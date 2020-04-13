# frozen_string_literal: true

module JSI
  # a MetaschemaNode is a PathedNode whose jsi_document contains a metaschema.
  # as with any PathedNode the jsi_ptr points to the content of a node.
  # the root of the metaschema is pointed to by metaschema_root_ptr.
  # the schema of the root of the document is represented by the BasicSchema `root_basic_schema`.
  #
  # like JSI::Base, this class represents an instance of a schema, an instance
  # which may itself be a schema. unlike JSI::Base, the document containing the
  # schema and the instance is the same, and a schema may be an instance of itself.
  #
  # the document containing the metaschema, its subschemas, and instances of those
  # subschemas is the jsi_document.
  #
  # the schema instance is the content in the document pointed to by the MetaschemaNode's jsi_ptr.
  #
  # unlike with JSI::Base, the schema is not part of the class, since a metaschema
  # needs the ability to have its schema be the instance itself.
  #
  # if the MetaschemaNode's schema is its self, it will be extended with JSI::Metaschema.
  #
  # a MetaschemaNode is extended with JSI::Schema when it represents a schema - this is the case when
  # its schema is the metaschema.
  class MetaschemaNode < Base
    def initialize(jsi_document, jsi_ptr: JSI::JSON::Pointer[], root_schema_ptrs: Set[JSI::JSON::Pointer[]], jsi_metaschema_module: , metaschema_root_ptr: JSI::JSON::Pointer[])
      @jsi_document = jsi_document
      @jsi_ptr = jsi_ptr
      raise(Bug, "root_basic_schema not BasicSchema") unless root_basic_schema.is_a?(BasicSchema)
      @root_schema_ptrs = root_basic_schema
      @metaschema_root_ptr = metaschema_root_ptr

      jsi_node_content = self.jsi_node_content

      if jsi_node_content.respond_to?(:to_hash)
        extend PathedHashNode
      elsif jsi_node_content.respond_to?(:to_ary)
        extend PathedArrayNode
      end

      instance_for_schema = jsi_document
      basic_schema_init = Set[root_basic_schema]
      basic_schemas = jsi_ptr.reference_tokens.inject(basic_schema_init) do |basic_schemas_under_tok, tok|
        subschemas_for_token = basic_schemas_under_tok.map do |basic_schema|
          if instance_for_schema.respond_to?(:to_ary)
            basic_schema.subschemas_for_index(tok)
          else
            basic_schema.subschemas_for_property_name(tok)
          end
        end.inject(Set.new, &:|)
        instance_for_schema = instance_for_schema[tok]
        basic_schemas_for_instance = subschemas_for_token.map do |basic_schema|
          basic_schema.match_to_instance(instance_for_schema)
        end.inject(Set.new, &:|)
        basic_schemas_for_instance
      end

      @jsi_schemas = basic_schemas.map do |basic_schema|
        if basic_schema.ptr == jsi_ptr
          self
        else
          new_node(jsi_ptr: basic_schema.ptr)
        end
      end

      @jsi_schemas.each do |schema|
        if schema.jsi_ptr == metaschema_root_ptr
          extend JSI::Schema
        end
        if schema.jsi_ptr == jsi_ptr
          extend Metaschema
        end
        extend(JSI::SchemaClasses.accessor_module_for_schema(schema, conflicting_modules: [Metaschema, Schema, MetaschemaNode, PathedArrayNode, PathedHashNode]))
      end

      # workarounds
      begin # draft 4 boolean schema workaround
        # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
        # properties/additionalProperties and properties/additionalItems.
        # we need to extend those as DescribesSchema.
        addtlPropsanyOf = metaschema_root_ptr["properties"]["additionalProperties"]["anyOf"]
        addtlItemsanyOf = metaschema_root_ptr["properties"]["additionalItems"]["anyOf"]

        if !jsi_ptr.root? && [addtlPropsanyOf, addtlItemsanyOf].include?(jsi_ptr.parent)
          extend JSI::Schema::DescribesSchema
        end
      end
    end

    attr_reader :xroot_basic_schema

    # ptr to the root of the metaschema in the jsi_document
    attr_reader :xmetaschema_root_ptr

    # JSI::Schemas describing this MetaschemaNode
    attr_reader :xjsi_schemas

    # @return [MetaschemaNode] document root MetaschemaNode
    def xjsi_root_node
      new_node(jsi_ptr: JSI::JSON::Pointer[])
    end

    # @return [MetaschemaNode] parent MetaschemaNode
    def xjsi_parent_node
      new_node(jsi_ptr: jsi_ptr.parent)
    end

    def xsubscript(token)
      result = jsi_memoize(:[], token, value, token_in_range) do |token, value, token_in_range|
        if token_in_range
          value_node = new_node(jsi_ptr: jsi_ptr[token])

          if value_node.is_a?(Schema) || value.respond_to?(:to_hash) || value.respond_to?(:to_ary)
            value_node
          else
            value
          end
        else
          # I think I will not support Hash#default/#default_proc in this case.
          nil
        end
      end
      result
    end

    # @return [Array<String>]
    def xjsi_object_group_text
      if jsi_schemas.any?
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

    private

    def xour_initialize_params
      {jsi_ptr: jsi_ptr, metaschema_root_ptr: metaschema_root_ptr, root_basic_schema: root_basic_schema}
    end

    def xnew_node(params)
      MetaschemaNode.new(jsi_document, our_initialize_params.merge(params))
    end
  end
end
