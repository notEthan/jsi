# frozen_string_literal: true

module JSI
  # a MetaschemaNode is a JSI instance representing a node in a document which contains a metaschema.
  # the root of the metaschema is pointed to by metaschema_root_ptr.
  # the schema describing the root of the document is pointed to by root_schema_ptr.
  #
  # like JSI::Base's normal subclasses, this class represents an instance of a schema set, an instance
  # which may itself be a schema. unlike JSI::Base, the document containing the instance and its schemas
  # is the same, and a schema (the metaschema) may be an instance of itself.
  #
  # unlike JSI::Base's normal subclasses, the schemas describing the instance are not part of the class.
  # since the metaschema describes itself, attempting to construct a class from the JSI Schema Module of a
  # schema which is itself an instance of that class results in a causality loop.
  # instead, a MetaschemaNode calculates its {#jsi_schemas} and extends itself with their JSI Schema
  # modules during initialization.
  # the MetaschemaNode of the metaschema is extended with its own JSI Schema Module.
  #
  # if the MetaschemaNode's schemas include its self, it is extended with JSI::Metaschema.
  #
  # a MetaschemaNode is extended with JSI::Schema when it represents a schema - this is the case when
  # the metaschema is one of its schemas.
  class MetaschemaNode < Base
    autoload :BootstrapSchema, 'jsi/metaschema_node/bootstrap_schema'

    # @param jsi_document the document containing the metaschema
    # @param jsi_ptr [JSI::Ptr] ptr to this MetaschemaNode in jsi_document
    # @param schema_implementation_modules [Enumerable<Module>] modules which implement the functionality
    #   of the schema. these are included on the {Schema#jsi_schema_module} of the metaschema.
    #   they extend any schema described by the metaschema, including those in the document containing
    #   the metaschema, and the metaschema itself.
    #   see {Schema#describes_schema!} param `schema_implementation_modules`.
    # @param metaschema_root_ptr [JSI::Ptr] ptr to the root of the metaschema in the jsi_document
    # @param root_schema_ptr [JSI::Ptr] ptr to the schema describing the root of the jsi_document
    def initialize(
        jsi_document,
        jsi_ptr: Ptr[],
        schema_implementation_modules: ,
        metaschema_root_ptr: Ptr[],
        root_schema_ptr: Ptr[],
        jsi_schema_base_uri: nil,
        jsi_root_node: nil
    )
      jsi_initialize_memos

      self.jsi_document = jsi_document
      self.jsi_ptr = jsi_ptr
      @schema_implementation_modules = Util.ensure_module_set(schema_implementation_modules)
      @metaschema_root_ptr = metaschema_root_ptr
      @root_schema_ptr = root_schema_ptr
      raise(Bug, 'jsi_root_node') if jsi_ptr.root? ^ !jsi_root_node
      @jsi_root_node = jsi_ptr.root? ? self : jsi_root_node

      if jsi_ptr.root? && jsi_schema_base_uri
        raise(NotImplementedError, "unsupported jsi_schema_base_uri on metaschema document root")
      end
      self.jsi_schema_base_uri = jsi_schema_base_uri

      jsi_node_content = self.jsi_node_content

      instance_for_schemas = jsi_document
      bootstrap_schema_class = JSI::SchemaClasses.bootstrap_schema_class(schema_implementation_modules)
      root_bootstrap_schema = bootstrap_schema_class.new(
        jsi_document,
        jsi_ptr: root_schema_ptr,
        jsi_schema_base_uri: nil, # supplying jsi_schema_base_uri on root bootstrap schema is not supported
      )
      our_bootstrap_schemas = jsi_ptr.tokens.inject(SchemaSet[root_bootstrap_schema]) do |bootstrap_schemas, tok|
        child_indicated_schemas = bootstrap_schemas.child_applicator_schemas(tok, instance_for_schemas)
        child_schemas = child_indicated_schemas.inplace_applicator_schemas(instance_for_schemas[tok])
        instance_for_schemas = instance_for_schemas[tok]
        child_schemas
      end

      our_bootstrap_schemas.each do |bootstrap_schema|
        if bootstrap_schema.jsi_ptr == metaschema_root_ptr
          # this is described by the metaschema, i.e. this is a schema
          schema_implementation_modules.each do |schema_implementation_module|
            extend schema_implementation_module
          end
        end
        if bootstrap_schema.jsi_ptr == jsi_ptr
          # this is the metaschema (it is described by itself)
          extend Metaschema
        end
      end

      @jsi_schemas = SchemaSet.new(our_bootstrap_schemas) do |bootstrap_schema|
        if bootstrap_schema.jsi_ptr == jsi_ptr
          self
        elsif bootstrap_schema.jsi_ptr.root?
          @jsi_root_node
        else
          new_node(
            jsi_ptr: bootstrap_schema.jsi_ptr,
            jsi_schema_base_uri: bootstrap_schema.jsi_schema_base_uri,
            jsi_root_node: @jsi_root_node,
          )
        end
      end

      # note: jsi_schemas must already be set for jsi_schema_module to be used/extended
      if is_a?(Metaschema)
        describes_schema!(schema_implementation_modules)
      end

      extends_for_instance = JSI::SchemaClasses.includes_for(jsi_node_content)
      extends_for_instance.each do |m|
        extend m
      end

      @jsi_schemas.each do |schema|
        extend schema.jsi_schema_module
      end

      # workarounds
      begin # draft 4 boolean schema workaround
        # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
        # properties/additionalProperties and properties/additionalItems.
        # these still describe schemas, despite not being described by the metaschema.
        addtlPropsanyOf = metaschema_root_ptr["properties"]["additionalProperties"]["anyOf"]
        addtlItemsanyOf = metaschema_root_ptr["properties"]["additionalItems"]["anyOf"]

        if !jsi_ptr.root? && [addtlPropsanyOf, addtlItemsanyOf].include?(jsi_ptr.parent)
          describes_schema!(schema_implementation_modules)
        end
      end
    end

    # Set of modules to apply to schemas which are instances of (described by) the metaschema
    # @return [Set<Module>]
    attr_reader :schema_implementation_modules

    # ptr to the root of the metaschema in the jsi_document
    # @return [JSI::Ptr]
    attr_reader :metaschema_root_ptr

    # ptr to the schema of the root of the jsi_document
    # @return [JSI::Ptr]
    attr_reader :root_schema_ptr

    # JSI Schemas describing this MetaschemaNode
    # @return [JSI::SchemaSet]
    attr_reader :jsi_schemas

    # subscripts to return a child value identified by the given token.
    #
    # @param token (see JSI::Base#[])
    # @param as_jsi (see JSI::Base#[])
    # @return (see JSI::Base#[])
    def [](token, as_jsi: :auto)
      begin
        if jsi_child_token_in_range?(token)
          value_node = jsi_subinstance_memos[token: token]

          jsi_subinstance_as_jsi(jsi_node_content_child(token), value_node.jsi_schemas, as_jsi) do
            value_node
          end
        else
          # I think I will not support Hash#default/#default_proc in this case.
          nil
        end
      end
    end

    # instantiates a new MetaschemaNode whose instance is a modified copy of this MetaschemaNode's instance
    # @yield [Object] the node content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [MetaschemaNode] modified copy of self
    def jsi_modified_copy(&block)
      if jsi_ptr.root?
        modified_document = jsi_ptr.modified_document_copy(jsi_document, &block)
        MetaschemaNode.new(modified_document, **our_initialize_params)
      else
        modified_jsi_root_node = jsi_root_node.jsi_modified_copy do |root|
          jsi_ptr.modified_document_copy(root, &block)
        end
        modified_jsi_root_node.jsi_descendent_node(jsi_ptr)
      end
    end

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      if jsi_schemas && jsi_schemas.any?
        class_n_schemas = "#{self.class} (#{jsi_schemas.map { |s| s.jsi_ptr.uri }.join(' ')})"
      else
        class_n_schemas = self.class.to_s
      end
      [
        class_n_schemas,
        is_a?(Metaschema) ? "Metaschema" : is_a?(Schema) ? "Schema" : nil,
        *(jsi_node_content.respond_to?(:jsi_object_group_text) ? jsi_node_content.jsi_object_group_text : []),
      ].compact
    end

    # an opaque fingerprint of this MetaschemaNode for FingerprintHash
    def jsi_fingerprint
      {class: self.class, jsi_document: jsi_document}.merge(our_initialize_params)
    end

    private

    # note: does not include jsi_root_node
    def our_initialize_params
      {
        jsi_ptr: jsi_ptr,
        schema_implementation_modules: schema_implementation_modules,
        metaschema_root_ptr: metaschema_root_ptr,
        root_schema_ptr: root_schema_ptr,
        jsi_schema_base_uri: jsi_schema_base_uri,
      }
    end

    # note: not for root node
    def new_node(params)
      MetaschemaNode.new(jsi_document, **our_initialize_params.merge(params))
    end

    def jsi_subinstance_memos
      jsi_memomap(:subinstance) do |token: |
        new_node(
          jsi_ptr: jsi_ptr[token],
          jsi_schema_base_uri: jsi_resource_ancestor_uri,
          jsi_root_node: jsi_root_node,
        )
      end
    end
  end
end
