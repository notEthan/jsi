# frozen_string_literal: true

module JSI
  # A MetaSchemaNode is a JSI instance representing a node in a document that contains a meta-schema.
  # The root of the meta-schema is pointed to by metaschema_root_ptr.
  # the schema describing the root of the document is pointed to by root_schema_ptr.
  #
  # like JSI::Base's normal subclasses, this class represents an instance of a schema set, an instance
  # which may itself be a schema. unlike JSI::Base, the document containing the instance and its schemas
  # is the same, and a schema (the meta-schema) may be an instance of itself.
  #
  # unlike JSI::Base's normal subclasses, the schemas describing the instance are not part of the class.
  # Since the meta-schema describes itself, attempting to construct a class from the JSI Schema Module of a
  # schema which is itself an instance of that class results in a causality loop.
  # instead, a MetaSchemaNode calculates its {#jsi_schemas} and extends itself with their JSI Schema
  # modules during initialization.
  # The MetaSchemaNode of the meta-schema is extended with its own JSI Schema Module.
  #
  # if the MetaSchemaNode's schemas include its self, it is extended with {JSI::Schema::MetaSchema}.
  #
  # a MetaSchemaNode is extended with JSI::Schema when it represents a schema - this is the case when
  # the meta-schema is one of its schemas.
  class MetaSchemaNode < Base
    autoload :BootstrapSchema, 'jsi/metaschema_node/bootstrap_schema'

    include(Base::Immutable)

    # @param jsi_document the document containing the meta-schema.
    #   this must be frozen recursively; MetaSchemaNode does support mutation.
    # @param jsi_ptr [JSI::Ptr] ptr to this MetaSchemaNode in jsi_document
    # @param msn_dialect [Schema::Dialect]
    # @param metaschema_root_ptr [JSI::Ptr] ptr to the root of the meta-schema in the jsi_document
    # @param root_schema_ptr [JSI::Ptr] ptr to the schema describing the root of the jsi_document
    # @param bootstrap_schema_registry [SchemaRegistry, nil]
    def initialize(
        jsi_document,
        jsi_ptr: Ptr[],
        msn_dialect: ,
        metaschema_root_ptr: Ptr[],
        root_schema_ptr: Ptr[],
        jsi_schema_base_uri: nil,
        jsi_schema_registry: nil,
        bootstrap_schema_registry: nil,
        jsi_content_to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
        initialize_finish: true,
        jsi_root_node: nil
    )
      super(jsi_document,
        jsi_ptr: jsi_ptr,
        jsi_indicated_schemas: SchemaSet[],
        jsi_schema_base_uri: jsi_schema_base_uri,
        jsi_schema_registry: jsi_schema_registry,
        jsi_content_to_immutable: jsi_content_to_immutable,
        jsi_root_node: jsi_root_node,
      )

      @initialize_finished = false
      @to_initialize_finish = []

      @msn_dialect = msn_dialect
      @metaschema_root_ptr = metaschema_root_ptr
      @root_schema_ptr = root_schema_ptr
      @bootstrap_schema_registry = bootstrap_schema_registry

      if jsi_ptr.root? && jsi_schema_base_uri
        raise(NotImplementedError, "unsupported jsi_schema_base_uri on meta-schema document root")
      end

      #chkbug fail(Bug, 'MetaSchemaNode instance must be frozen') unless jsi_node_content.frozen?

      instance_for_schemas = jsi_document
      bootstrap_schema_class = msn_dialect.bootstrap_schema_class
      root_bootstrap_schema = bootstrap_schema_class.new(
        jsi_document,
        jsi_ptr: root_schema_ptr,
        jsi_schema_base_uri: nil, # supplying jsi_schema_base_uri on root bootstrap schema is not supported
        jsi_schema_registry: bootstrap_schema_registry,
      )
      our_bootstrap_indicated_schemas = jsi_ptr.tokens.inject(SchemaSet[root_bootstrap_schema]) do |bootstrap_indicated_schemas, tok|
        child_indicated_schemas = bootstrap_indicated_schemas.each_yield_set do |is, y|
          is.each_inplace_child_applicator_schema(tok, instance_for_schemas, &y)
        end
        instance_for_schemas = instance_for_schemas[tok]
        child_indicated_schemas
      end
      @indicated_schemas_map = jsi_memomap { bootstrap_schemas_to_msn(our_bootstrap_indicated_schemas) }

      @bootstrap_schemas = our_bootstrap_indicated_schemas.each_yield_set do |is, y|
        is.each_inplace_applicator_schema(instance_for_schemas, &y)
      end

      @bootstrap_schemas.each do |bootstrap_schema|
        if bootstrap_schema.jsi_ptr == metaschema_root_ptr
          # this is described by the meta-schema, i.e. this is a schema
          define_singleton_method(:dialect) { msn_dialect }
          extend(Schema)
        end
      end

      @jsi_schemas = @bootstrap_schemas

      jsi_initialize_finish if initialize_finish
    end

    private def jsi_initialize_finish
      return if @initialize_finished

      @jsi_schemas = bootstrap_schemas_to_msn(@bootstrap_schemas)

      # note: jsi_schemas must already be set for jsi_schema_module to be used/extended
      if jsi_ptr == metaschema_root_ptr
        describes_schema!(msn_dialect)
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
        node.send(:jsi_initialize_finish)
      end
    end

    # @return [Schema::Dialect]
    attr_reader(:msn_dialect)

    # ptr to the root of the meta-schema in the jsi_document
    # @return [JSI::Ptr]
    attr_reader :metaschema_root_ptr

    # ptr to the schema of the root of the jsi_document
    # @return [JSI::Ptr]
    attr_reader :root_schema_ptr

    # @return [SchemaRegistry, nil]
    attr_reader(:bootstrap_schema_registry)

    # JSI Schemas describing this MetaSchemaNode
    # @return [JSI::SchemaSet]
    attr_reader :jsi_schemas

    # See {Base#jsi_indicated_schemas}
    # @return [JSI::SchemaSet]
    def jsi_indicated_schemas
      @indicated_schemas_map[]
    end

    # see {Base#jsi_child}
    def jsi_child(token, as_jsi: )
      child_node = root_descendent_node(jsi_ptr[token])

      jsi_child_as_jsi(child_node.jsi_node_content, child_node.jsi_schemas, as_jsi) do
        child_node
      end
    end
    private :jsi_child

    # See {Base#jsi_default_child}
    def jsi_default_child(token, as_jsi: )
      jsi_node_content_child(token)
    end
    private :jsi_default_child # internals for #[] but idk, could be public

    # instantiates a new MetaSchemaNode whose instance is a modified copy of this MetaSchemaNode's instance
    # @yield [Object] the node content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [MetaSchemaNode] modified copy of self
    def jsi_modified_copy(&block)
      if jsi_ptr.root?
        modified_document = jsi_ptr.modified_document_copy(jsi_document, &block)
        modified_document = jsi_content_to_immutable.call(modified_document) if jsi_content_to_immutable
        MetaSchemaNode.new(modified_document, **our_initialize_params)
      else
        modified_jsi_root_node = jsi_root_node.jsi_modified_copy do |root|
          jsi_ptr.modified_document_copy(root, &block)
        end
        modified_jsi_root_node.jsi_descendent_node(jsi_ptr)
      end
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {class: self.class, jsi_document: jsi_document}.merge(our_initialize_params).freeze
    end

    protected

    attr_reader :root_descendent_node_map

    private

    def jsi_memomaps_initialize
      if jsi_ptr.root?
        @root_descendent_node_map = jsi_memomap(&method(:jsi_root_descendent_node_compute))
      else
        @root_descendent_node_map = @jsi_root_node.root_descendent_node_map
      end
    end

    # note: does not include jsi_root_node
    def our_initialize_params
      {
        jsi_ptr: jsi_ptr,
        msn_dialect: msn_dialect,
        metaschema_root_ptr: metaschema_root_ptr,
        root_schema_ptr: root_schema_ptr,
        jsi_schema_base_uri: jsi_schema_base_uri,
        jsi_schema_registry: jsi_schema_registry,
        bootstrap_schema_registry: bootstrap_schema_registry,
        jsi_content_to_immutable: jsi_content_to_immutable,
      }.freeze
    end

    def jsi_root_descendent_node_compute(ptr: )
      #chkbug fail(Bug) unless jsi_ptr.root?
      if ptr.root?
        self
      else
        MetaSchemaNode.new(jsi_document,
          **our_initialize_params,
          jsi_ptr: ptr,
          jsi_schema_base_uri: jsi_resource_ancestor_uri,
          jsi_root_node: jsi_root_node,
          initialize_finish: false,
        )
      end
    end

    # @param ptr [Ptr]
    # @return [MetaSchemaNode]
    private def root_descendent_node(ptr)
      node = @root_descendent_node_map[
        ptr: ptr,
      ]

      if @initialize_finished
        node.send(:jsi_initialize_finish)
      else
        @to_initialize_finish.push(node)
      end

      node
    end

    # @param bootstrap_schemas [Enumerable<BootstrapSchema>]
    # @return [SchemaSet<MetaSchemaNode>]
    def bootstrap_schemas_to_msn(bootstrap_schemas)
      SchemaSet.new(bootstrap_schemas) do |bootstrap_schema|
        root_descendent_node(bootstrap_schema.jsi_ptr)
      end
    end
  end
end
