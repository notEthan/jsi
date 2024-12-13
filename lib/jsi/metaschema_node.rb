# frozen_string_literal: true

module JSI
  # A MetaSchemaNode is a JSI instance representing a node in a document that contains a meta-schema,
  # or contains a schema describing a meta-schema (e.g. a meta-schema vocabulary schema).
  #
  # A meta-schema typically has the unique property that it is an instance of itself.
  # It may also be an instance of a number of other schemas, each of which
  # may be an instance of the meta-schema, itself, and/or other schemas.
  #
  # This is not a configuration of schemas/instances that normal JSI::Base instantiation can accommodate.
  # MetaSchemaNode instead bootstraps each node on initialization, computing and instantiating
  # the schemas that describe it (other MetaSchemaNode instances) and their schema modules.
  # This results in a node that is a meta-schema being an instance of its own schema module
  # (as well as JSI::Schema and JSI::Schema::MetaSchema), and a node that is a schema being an instance of
  # the meta-schema's schema module (and thereby JSI::Schema).
  #
  # The meta-schema may be anywhere in a document, though it is rare to put it anywhere but at the root.
  # The root of the meta-schema is referenced by the {MetaSchemaNode::Conf configured}
  # {MetaSchemaNode::Conf#metaschema_root_ref `metaschema_root_ref`}.
  # The schema describing the root of the document is referenced by the configured
  # {MetaSchemaNode::Conf#root_schema_ref `root_schema_ref`}.
  class MetaSchemaNode < Base
    autoload :BootstrapSchema, 'jsi/metaschema_node/bootstrap_schema'

    # @private - experimental
    # `self` is a MetaSchemaNode
    # @param node [MetaSchemaNode, MetaSchemaNode::BootstrapSchema]
    # @return [Boolean] is `node` a meta-schema?
    DEFAULT_IS_METASCHEMA = proc do |node|
      node.jsi_document.equal?(@bootstrap_metaschema.jsi_document) && node.jsi_ptr == @bootstrap_metaschema.jsi_ptr
    end
    private_constant(:DEFAULT_IS_METASCHEMA)

    include(Base::Immutable)

    Conf = Base::Conf.subclass(*%i(
      dialect
      metaschema_root_ref
      root_schema_ref
      bootstrap_registry
      is_metaschema
    ))

    # {Base::Conf} with additional configuration for MetaSchemaNode.
    #
    # @!attribute dialect
    #   @return [Schema::Dialect]
    # @!attribute metaschema_root_ref
    #   URI reference to the root of the meta-schema.
    #
    #   Default: `"#"` resolves to the root of the `jsi_document`.
    #   @return [Addressable::URI]
    # @!attribute root_schema_ref
    #   URI reference to the schema describing the root of the jsi_document.
    #   When schemas of the meta-schema are in multiple documents, this describes the roots of all instantiated documents.
    #
    #   Default: `metaschema_root_ref` value, i.e. the document root is a schema.
    #   @return [Addressable::URI]
    # @!attribute bootstrap_registry
    #   Default: nil
    #   @return [Registry, nil]
    class Conf < Base::Conf
      def initialize(
          dialect: ,
          metaschema_root_ref: '#',
          root_schema_ref: metaschema_root_ref,
          registry: nil, # overrides Base::Conf default value JSI.registry
          is_metaschema: DEFAULT_IS_METASCHEMA,
          **kw
      )
        super(
          dialect: dialect,
          metaschema_root_ref: Util.uri(metaschema_root_ref, nnil: true),
          root_schema_ref: Util.uri(root_schema_ref, nnil: true),
          registry: registry,
          is_metaschema: is_metaschema,
          **kw,
        )
      end
    end

    # See {JSI.new_metaschema_node} to instantiate.
    #
    # Note: when instantiating MetaSchemaNode directly, the caller must invoke #jsi_initialize_finish.
    # @api private
    # @param jsi_document the document containing the meta-schema.
    #   this must be frozen recursively; MetaSchemaNode does support mutation.
    # @param jsi_ptr [JSI::Ptr] ptr to this MetaSchemaNode in jsi_document
    def initialize(
        jsi_document,
        jsi_ptr: Ptr[],
        jsi_root_node: nil,
        **kw
    )
      super(jsi_document,
        jsi_ptr: jsi_ptr,
        jsi_indicated_schemas: SchemaSet[],
        # MSN doesn't track schema_resource_ancestors through descendents, but the root is included when appropriate
        jsi_schema_resource_ancestors: jsi_ptr.root? || !jsi_root_node.is_a?(Schema) ? Util::EMPTY_ARY : [jsi_root_node].freeze,
        jsi_root_node: jsi_root_node,
        **kw,
      )

      @initialize_finish_started = false
      @initialize_finished = false
      @to_initialize_finish = []

      if jsi_ptr.root? && jsi_base_uri
        raise(NotImplementedError, "unsupported jsi_base_uri on meta-schema document root")
      end

      #chkbug fail(Bug, 'MetaSchemaNode instance must be frozen') unless jsi_node_content.frozen?

      bootstrap_schema_from_ref = proc do |ref_uri|
        ref_uri_nofrag = ref_uri.merge(fragment: nil)

        if ref_uri_nofrag.empty?
          ptr = Ptr.from_fragment(ref_uri.fragment).resolve_against(jsi_document) # anchor not supported
          jsi_conf.dialect.bootstrap_schema(
            jsi_document,
            jsi_ptr: ptr,
            jsi_base_uri: nil, # not supported
            jsi_registry: jsi_conf.bootstrap_registry,
          )
        else
          # if not fragment-only, ref must be registered in the bootstrap_registry
          ref = Schema::Ref.new(ref_uri, registry: jsi_conf.bootstrap_registry)
          ref.resolve
        end
      end

      @bootstrap_metaschema = bootstrap_schema_from_ref[jsi_conf.metaschema_root_ref]

      instance_for_schemas = jsi_document
      root_bootstrap_schema = bootstrap_schema_from_ref[jsi_conf.root_schema_ref]
      our_bootstrap_indicated_schemas = jsi_ptr.tokens.inject(SchemaSet[root_bootstrap_schema]) do |bootstrap_indicated_schemas, tok|
        child_indicated_schemas = bootstrap_indicated_schemas.each_yield_set do |is, y|
          is.each_inplace_child_applicator_schema(tok, instance_for_schemas,
            collect_evaluated_validate: jsi_conf.application_collect_evaluated_validate,
            &y
          )
        end
        instance_for_schemas = instance_for_schemas[tok]
        child_indicated_schemas
      end
      @indicated_schemas_map = jsi_memomap do
        SchemaSet.new(our_bootstrap_indicated_schemas) { |s| bootstrap_schema_to_msn(s) }
      end

      @bootstrap_schemas = our_bootstrap_indicated_schemas.each_yield_set do |is, y|
        is.each_inplace_applicator_schema(instance_for_schemas, &y) # note: instance_for_schemas == jsi_node_content now
      end

      @jsi_schemas = @bootstrap_schemas

      @bootstrap_schemas.each do |bootstrap_schema|
        if instance_exec(bootstrap_schema, &jsi_conf.is_metaschema)
          # this is described by the meta-schema, i.e. this is a schema
          define_singleton_method(:dialect) { jsi_conf.dialect }
          extend(Schema)

          if jsi_registry && jsi_resource_uris.any? { |uri| !jsi_registry.registered?(uri) }
            jsi_registry.register_immediate(self)
          end
        end
      end
    end

    # @api private
    def jsi_initialize_finish
      return self if @initialize_finish_started
      @initialize_finish_started = true

      @jsi_schemas = SchemaSet.new(@bootstrap_schemas) { |s| bootstrap_schema_to_msn(s) }

      # note: jsi_schemas must already be set for jsi_schema_module to be used/extended
      if instance_exec(self, &jsi_conf.is_metaschema)
        describes_schema!(jsi_conf.dialect)
      end

      extends_for_instance = JSI::SchemaClasses.includes_for(jsi_node_content)

      conflicting_modules = Set[self.class] + extends_for_instance + @jsi_schemas.map(&:jsi_schema_module)
      reader_modules = @jsi_schemas.map do |schema|
        JSI::SchemaClasses.schema_property_reader_module(schema, conflicting_modules: conflicting_modules)
      end

      readers = reader_modules.map(&:jsi_property_readers).inject(Set[], &:merge).freeze
      define_singleton_method(:jsi_property_readers) { readers }

      reader_modules.each { |reader_module| extend reader_module }

      extends_for_instance.each do |m|
        extend m
      end

      @jsi_schemas.each do |schema|
        extend schema.jsi_schema_module
      end

      @initialize_finished = true
      while !@to_initialize_finish.empty?
        node = @to_initialize_finish.shift
        node.jsi_initialize_finish
      end

      jsi_initialized
    end

    # JSI Schemas describing this MetaSchemaNode
    # @return [JSI::SchemaSet]
    attr_reader :jsi_schemas

    # See {Base#jsi_indicated_schemas}
    # @return [JSI::SchemaSet]
    def jsi_indicated_schemas
      @indicated_schemas_map[]
    end

    # see {Base#jsi_child_node}
    def jsi_child_node(token)
      root_descendent_node(jsi_ptr[token], dynamic_anchor_map: jsi_schema_dynamic_anchor_map)
    end

    # See {Base#jsi_default_child}
    def jsi_default_child(token, as_jsi: )
      jsi_node_content_child(token)
    end
    private :jsi_default_child # internals for #[] but idk, could be public

    # @raise [NotImplementedError] not implemented for MetaSchemaNode
    def jsi_modified_copy(**)
      # this had an implementation previously (see git history). but for 2020-12, support for multiple
      # mutually-descriptive schemas as well as dynamic scope makes instantiating a modified copy that
      # preserves self-descriptive/mutually-descriptive relationships generally infeasible.
      raise(NotImplementedError)
    end

    # @private
    # @param dynamic_anchor_map [Schema::DynamicAnchorMap]
    # @return [MetaSchemaNode]
    def jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
      return(self) if dynamic_anchor_map == jsi_schema_dynamic_anchor_map
      new_dynamic_anchor_map = dynamic_anchor_map.without_node(self)
      return(self) if new_dynamic_anchor_map == jsi_schema_dynamic_anchor_map

      root_descendent_node(jsi_ptr, dynamic_anchor_map: new_dynamic_anchor_map)
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        jsi_base_uri: jsi_base_uri,
        jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
        dialect: jsi_conf.dialect,
        metaschema_root_ref: jsi_conf.metaschema_root_ref,
        root_schema_ref: jsi_conf.root_schema_ref,
        jsi_registry: jsi_registry,
        bootstrap_registry: jsi_conf.bootstrap_registry,
      }.freeze
    end

    protected

    attr_reader :root_descendent_node_map

    private

    def jsi_memomaps_initialize
      if equal?(@jsi_root_node)
        @root_descendent_node_map = jsi_memomap(&method(:jsi_root_descendent_node_compute))
      else
        @root_descendent_node_map = @jsi_root_node.root_descendent_node_map
      end
    end

    def jsi_root_descendent_node_compute(ptr: , dynamic_anchor_map: )
      # note: self is jsi_root_node
      #chkbug fail(Bug) unless equal?(jsi_root_node)
      #chkbug fail if dynamic_anchor_map != dynamic_anchor_map.without_node(self, ptr: ptr)
      if ptr.root? && dynamic_anchor_map == jsi_schema_dynamic_anchor_map
        self
      else
        MetaSchemaNode.new(jsi_document,
          jsi_ptr: ptr,
          jsi_base_uri: ptr.root? ? nil : jsi_resource_ancestor_uri,
          jsi_schema_dynamic_anchor_map: dynamic_anchor_map,
          jsi_root_node: jsi_root_node,
        )
      end
    end

    # @param ptr [Ptr]
    # @param dynamic_anchor_map [Schema::DynamicAnchorMap] must be `without_node(..., ptr: ptr)` or so
    # @return [MetaSchemaNode]
    protected def root_descendent_node(ptr, dynamic_anchor_map: )
      to_initialize_finish(@root_descendent_node_map[
        ptr: ptr.resolve_against(jsi_document),
        dynamic_anchor_map: dynamic_anchor_map,
      ])
    end

    def to_initialize_finish(node)
      if @initialize_finished
        node.jsi_initialize_finish
      else
        @to_initialize_finish.push(node)
      end

      node
    end

    # @param bootstrap_schema [MetaSchemaNode::BootstrapSchema]
    # @return [MetaSchemaNode]
    def bootstrap_schema_to_msn(bootstrap_schema)
      dynamic_anchor_map = Schema::DynamicAnchorMap::EMPTY
      bootstrap_schema.jsi_schema_dynamic_anchor_map.each do |anchor, (bootstrap_anchor_root, anchor_ptrs)|
        msn_anchor_root = bootstrap_schema_to_msn(bootstrap_anchor_root)
        dynamic_anchor_map = dynamic_anchor_map.merge({
          anchor => [msn_anchor_root, anchor_ptrs].freeze,
        }).freeze
      end

      if bootstrap_schema.jsi_document.equal?(jsi_document)
        root_descendent_node(bootstrap_schema.jsi_ptr, dynamic_anchor_map: dynamic_anchor_map)
      else
        jsi_registry || raise(ResolutionError, "no jsi_registry")
        bootstrap_resource = bootstrap_schema.jsi_resource_root
        resource_uri = bootstrap_resource.jsi_resource_uri || raise(ResolutionError, "no URI: #{bootstrap_resource}")
        if jsi_registry.registered?(resource_uri)
          resource = jsi_registry.find(resource_uri)
          relative_ptr = bootstrap_schema.jsi_ptr.relative_to(bootstrap_resource.jsi_ptr)
          resource.jsi_descendent_node(relative_ptr).jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
        else
          root = to_initialize_finish(MetaSchemaNode.new(
            bootstrap_schema.jsi_document,
            jsi_ptr: Ptr[],
            jsi_base_uri: nil,
            jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
            jsi_conf: jsi_conf,
          ))
          root.jsi_descendent_node(bootstrap_schema.jsi_ptr).jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
        end
      end
    end
  end
end
