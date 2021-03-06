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
    # @param jsi_ptr [JSI::JSON::Pointer] ptr to this MetaschemaNode in jsi_document
    # @param metaschema_instance_modules [Set<Module>] modules which implement the functionality of the
    #   schema, to be applied to every schema which is an instance of the metaschema. this must include
    #   JSI::Schema directly or indirectly. these are the {Schema#jsi_schema_instance_modules} of the
    #   metaschema.
    # @param metaschema_root_ptr [JSI::JSON::Pointer] ptr to the root of the metaschema in the jsi_document
    # @param root_schema_ptr [JSI::JSON::Pointer] ptr to the schema describing the root of the jsi_document
    def initialize(
        jsi_document,
        jsi_ptr: JSI::JSON::Pointer[],
        metaschema_instance_modules: ,
        metaschema_root_ptr: JSI::JSON::Pointer[],
        root_schema_ptr: JSI::JSON::Pointer[],
        jsi_schema_base_uri: nil
    )
      jsi_initialize_memos

      self.jsi_document = jsi_document
      self.jsi_ptr = jsi_ptr
      @metaschema_instance_modules = metaschema_instance_modules
      @metaschema_root_ptr = metaschema_root_ptr
      @root_schema_ptr = root_schema_ptr

      if jsi_ptr.root? && jsi_schema_base_uri
        raise(NotImplementedError, "unsupported jsi_schema_base_uri on metaschema document root")
      end
      self.jsi_schema_base_uri = jsi_schema_base_uri

      jsi_node_content = self.jsi_node_content

      if jsi_node_content.respond_to?(:to_hash)
        extend PathedHashNode
      end
      if jsi_node_content.respond_to?(:to_ary)
        extend PathedArrayNode
      end

      instance_for_schemas = jsi_document
      bootstrap_schema_class = JSI::SchemaClasses.bootstrap_schema_class(metaschema_instance_modules)
      root_bootstrap_schema = bootstrap_schema_class.new(
        jsi_document,
        jsi_ptr: root_schema_ptr,
        jsi_schema_base_uri: nil, # supplying jsi_schema_base_uri on root bootstrap schema is not supported
      )
      our_bootstrap_schemas = jsi_ptr.reference_tokens.inject(SchemaSet[root_bootstrap_schema]) do |bootstrap_schemas, tok|
        subschemas_for_token = bootstrap_schemas.map do |bootstrap_schema|
          if instance_for_schemas.respond_to?(:to_ary)
            bootstrap_schema.subschemas_for_index(tok)
          else
            bootstrap_schema.subschemas_for_property_name(tok)
          end
        end.inject(SchemaSet[], &:|)
        instance_for_schemas = instance_for_schemas[tok]
        bootstrap_schemas_for_instance = subschemas_for_token.map do |bootstrap_schema|
          bootstrap_schema.match_to_instance(instance_for_schemas)
        end.inject(SchemaSet[], &:|)
        bootstrap_schemas_for_instance
      end

      our_bootstrap_schemas.each do |bootstrap_schema|
        if bootstrap_schema.jsi_ptr == metaschema_root_ptr
          metaschema_instance_modules.each do |metaschema_instance_module|
            extend metaschema_instance_module
          end
        end
        if bootstrap_schema.jsi_ptr == jsi_ptr
          extend Metaschema
          self.jsi_schema_instance_modules = metaschema_instance_modules
        end
      end

      @jsi_schemas = SchemaSet.new(our_bootstrap_schemas) do |bootstrap_schema|
        if bootstrap_schema.jsi_ptr == jsi_ptr
          self
        else
          new_node(
            jsi_ptr: bootstrap_schema.jsi_ptr,
            jsi_schema_base_uri: bootstrap_schema.jsi_schema_base_uri,
          )
        end
      end

      @jsi_schemas.each do |schema|
        extend schema.jsi_schema_module
      end

      # workarounds
      begin # draft 4 boolean schema workaround
        # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
        # properties/additionalProperties and properties/additionalItems.
        # since these describe schemas, their jsi_schema_instance_modules are the metaschema_instance_modules.
        addtlPropsanyOf = metaschema_root_ptr["properties"]["additionalProperties"]["anyOf"]
        addtlItemsanyOf = metaschema_root_ptr["properties"]["additionalItems"]["anyOf"]

        if !jsi_ptr.root? && [addtlPropsanyOf, addtlItemsanyOf].include?(jsi_ptr.parent)
          self.jsi_schema_instance_modules = metaschema_instance_modules
        end
      end
    end

    # Set of modules to apply to schemas which are instances of (described by) the metaschema
    attr_reader :metaschema_instance_modules

    # ptr to the root of the metaschema in the jsi_document
    attr_reader :metaschema_root_ptr
    # ptr to the schema of the root of the jsi_document
    attr_reader :root_schema_ptr
    # JSI::Schemas describing this MetaschemaNode
    attr_reader :jsi_schemas

    # @return [MetaschemaNode] document root MetaschemaNode
    def jsi_root_node
      if jsi_ptr.root?
        self
      else
        new_node(
          jsi_ptr: JSI::JSON::Pointer[],
          jsi_schema_base_uri: nil,
        )
      end
    end

    # @return [MetaschemaNode] parent MetaschemaNode
    def jsi_parent_node
      jsi_ptr.parent.evaluate(jsi_root_node)
    end

    # @param token [String, Integer, Object] the token to subscript
    # @param as_jsi (see JSI::Base#[])
    # @return [MetaschemaNode, Object] the node content's subscript value at the given token.
    #   if there is a subschema defined for that token on this MetaschemaNode's schema,
    #   returns that value as a MetaschemaNode instantiation of that subschema.
    def [](token, as_jsi: :auto)
      if respond_to?(:to_hash)
        token_in_range = jsi_node_content_hash_pubsend(:key?, token)
        value = jsi_node_content_hash_pubsend(:[], token)
      elsif respond_to?(:to_ary)
        token_in_range = jsi_node_content_ary_pubsend(:each_index).include?(token)
        value = jsi_node_content_ary_pubsend(:[], token)
      else
        raise(NoMethodError, "cannot subcript (using token: #{token.inspect}) from content: #{jsi_node_content.pretty_inspect.chomp}")
      end

      begin
        if token_in_range
          value_node = jsi_subinstance_memos[token]

          jsi_subinstance_as_jsi(value, value_node.jsi_schemas, as_jsi) do
            value_node
          end
        else
          # I think I will not support Hash#default/#default_proc in this case.
          nil
        end
      end
    end

    # @yield [Object] the node content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [MetaschemaNode] modified copy of self
    def jsi_modified_copy(&block)
      MetaschemaNode.new(jsi_ptr.modified_document_copy(jsi_document, &block), our_initialize_params)
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

    # @return [Object] an opaque fingerprint of this MetaschemaNode for FingerprintHash
    def jsi_fingerprint
      {class: self.class, jsi_document: jsi_document}.merge(our_initialize_params)
    end

    private

    def our_initialize_params
      {
        jsi_ptr: jsi_ptr,
        metaschema_instance_modules: metaschema_instance_modules,
        metaschema_root_ptr: metaschema_root_ptr,
        root_schema_ptr: root_schema_ptr,
        jsi_schema_base_uri: jsi_schema_base_uri,
      }
    end

    def new_node(params)
      MetaschemaNode.new(jsi_document, our_initialize_params.merge(params))
    end

    def jsi_subinstance_memos
      jsi_memomap(:subinstance) do |token|
        new_node(
          jsi_ptr: jsi_ptr[token],
          jsi_schema_base_uri: is_a?(Schema) ? jsi_subschema_base_uri : jsi_schema_base_uri,
        )
      end
    end
  end
end
