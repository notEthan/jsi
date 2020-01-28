# frozen_string_literal: true

module JSI
  # a MetaschemaNode is a PathedNode whose jsi_document contains a metaschema.
  # as with any PathedNode the jsi_ptr points to the content of a node.
  # the root of the metaschema is pointed to by metaschema_root_ptr.
  # the schema of the root of the document is pointed to by root_schema_ptr.
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
  class MetaschemaNode
    include PathedNode
    include Util::Memoize

    # not every MetaschemaNode is actually an Enumerable, but it's better to include Enumerable on
    # the class than to conditionally extend the instance.
    include Enumerable

    # @param jsi_document the document containing the metaschema
    # @param jsi_ptr [JSI::JSON::Pointer] ptr to this MetaschemaNode in jsi_document
    # @param metaschema_root_ptr [JSI::JSON::Pointer] ptr to the root of the metaschema in jsi_document
    # @param root_schema_ptr [JSI::JSON::Pointer] ptr to the schema of the root of the jsi_document
    # @param schema_documents [Array<Object>]
    def initialize(jsi_document, jsi_ptr: JSI::JSON::Pointer[], metaschema_root_ptr: JSI::JSON::Pointer[], root_schema_ptr: JSI::SchemaPointer[], schema_documents: nil)
      @jsi_document = jsi_document
      @jsi_ptr = jsi_ptr
      @metaschema_root_ptr = metaschema_root_ptr
      @root_schema_ptr = root_schema_ptr
      @schema_documents = schema_documents

      jsi_node_content = self.jsi_node_content

      if jsi_node_content.respond_to?(:to_hash)
        extend PathedHashNode
      elsif jsi_node_content.respond_to?(:to_ary)
        extend PathedArrayNode
      end

      instance_for_schema = jsi_document
      schema_doc_ptr_init = Set.new << {doc: jsi_document, ptr: root_schema_ptr}
      schema_doc_ptrs = jsi_ptr.reference_tokens.inject(schema_doc_ptr_init) do |doc_ptrs, tok|
        subschema_doc_ptrs_for_token = doc_ptrs.map do |doc_ptr|
          doc, ptr = doc_ptr[:doc], doc_ptr[:ptr]
          if ptr == @metaschema_root_ptr && schema_documents
            documents = schema_documents
          else
            documents = [doc]
          end
          documents.map do |schema_document|
            if instance_for_schema.respond_to?(:to_ary)
              subschema_ptrs = ptr.schema_subschema_ptrs_for_index(schema_document, tok)
            else
              subschema_ptrs = ptr.schema_subschema_ptrs_for_property_name(schema_document, tok)
            end
            subschema_ptrs.map do |subschema_ptr|
              {doc: schema_document, ptr: subschema_ptr}
            end
          end.inject(Set.new, &:|)
        end.inject(Set.new, &:|)
        instance_for_schema = instance_for_schema[tok]
        doc_ptrs_for_instance = subschema_doc_ptrs_for_token.map do |doc_ptr|
          doc_ptr[:ptr].schema_match_ptrs_to_instance(doc_ptr[:doc], instance_for_schema).map do |ptr|
            {doc: doc_ptr[:doc], ptr: ptr}
          end
        end.inject(Set.new, &:|)
        doc_ptrs_for_instance
      end

      if schema_ptrs.include?(metaschema_root_ptr)
        @jsi_ptr = jsi_ptr.as(JSI::SchemaPointer)
      end

      @jsi_schemas = schema_doc_ptrs.map do |schema_doc_ptr|
        if schema_doc_ptr[:ptr] == jsi_ptr && (schema_doc_ptr[:doc] == jsi_document || (jsi_ptr == @metaschema_root_ptr && schema_documents))
          self
        else
          MetaschemaNode.new(schema_doc_ptr[:doc], our_initialize_params.merge(jsi_ptr: schema_doc_ptr[:ptr]))
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

    # document containing the metaschema. see PathedNode#jsi_document.
    attr_reader :jsi_document
    # ptr to this metaschema node. see PathedNode#jsi_ptr.
    attr_reader :jsi_ptr
    # ptr to the root of the metaschema in the jsi_document
    attr_reader :metaschema_root_ptr
    # ptr to the schema of the root of the jsi_document
    attr_reader :root_schema_ptr
    # JSI::Schemas describing this MetaschemaNode
    attr_reader :jsi_schemas
    # documents containing the metaschema, or nil if the metaschema is contained only in jsi_document
    attr_reader :schema_documents

    # @return [MetaschemaNode] document root MetaschemaNode
    def jsi_root_node
      new_node(jsi_ptr: JSI::JSON::Pointer[])
    end

    # @return [Array<JSI::MetaschemaNode>]
    def jsi_parent_nodes
      parent = jsi_root_node

      jsi_ptr.reference_tokens.map do |token|
        parent.tap do
          parent = parent[token]
        end
      end.reverse
    end

    # @return [MetaschemaNode] parent MetaschemaNode
    def jsi_parent_node
      new_node(jsi_ptr: jsi_ptr.parent)
    end

    # @param token [String, Integer, Object] the token to subscript
    # @return [MetaschemaNode, Object] the node content's subscript value at the given token.
    #   if there is a subschema defined for that token on this MetaschemaNode's schema,
    #   returns that value as a MetaschemaNode instantiation of that subschema.
    def [](token)
      if respond_to?(:to_hash)
        token_in_range = jsi_node_content_hash_pubsend(:key?, token)
        value = jsi_node_content_hash_pubsend(:[], token)
      elsif respond_to?(:to_ary)
        token_in_range = jsi_node_content_ary_pubsend(:each_index).include?(token)
        value = jsi_node_content_ary_pubsend(:[], token)
      else
        raise(NoMethodError, "cannot subcript (using token: #{token.inspect}) from content: #{jsi_node_content.pretty_inspect.chomp}")
      end

      jsi_memoize(:[], token, value, token_in_range) do |token, value, token_in_range|
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
    end

    # if this MetaschemaNode is a $ref then the $ref is followed. otherwise this MetaschemaNode is returned.
    # @return [MetaschemaNode]
    def deref(&block)
      jsi_ptr_deref do |deref_ptr|
        return new_node(jsi_ptr: deref_ptr).tap(&(block || Util::NOOP))
      end
      return self
    end

    # @yield [Object] the node content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [MetaschemaNode] modified copy of self
    def modified_copy(&block)
      MetaschemaNode.new(jsi_ptr.modified_document_copy(jsi_document, &block), our_initialize_params)
    end

    # @return [String]
    def inspect
      "\#<#{object_group_text.join(' ')} #{jsi_node_content.inspect}>"
    end

    def pretty_print(q)
      q.text '#<'
      q.text object_group_text.join(' ')
      q.group_sub {
        q.nest(2) {
          q.breakable ' '
          q.pp jsi_node_content
        }
      }
      q.breakable ''
      q.text '>'
    end

    # @return [Array<String>]
    def object_group_text
      if jsi_schemas.any?
        class_n_schemas = "#{self.class} (#{jsi_schemas.map { |s| s.jsi_schema_module.name_from_ancestor || s.jsi_ptr.fragment }.join(', ')})"
      else
        class_n_schemas = self.class.to_s
      end
      [
        class_n_schemas,
        is_a?(Metaschema) ? "Metaschema" : is_a?(Schema) ? "Schema" : nil,
        *(jsi_node_content.respond_to?(:object_group_text) ? jsi_node_content.object_group_text : []),
      ].compact
    end

    # @return [Object] an opaque fingerprint of this MetaschemaNode for FingerprintHash
    def jsi_fingerprint
      {class: self.class, jsi_document: jsi_document}.merge(our_initialize_params)
    end
    include Util::FingerprintHash

    private

    def our_initialize_params
      {jsi_ptr: jsi_ptr, metaschema_root_ptr: metaschema_root_ptr, root_schema_ptr: root_schema_ptr, schema_documents: schema_documents}
    end

    def new_node(params)
      MetaschemaNode.new(jsi_document, our_initialize_params.merge(params))
    end
  end
end
