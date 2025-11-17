# frozen_string_literal: true

module JSI
  # internal class to bootstrap a meta-schema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  #
  # this class is to only be instantiated on nodes in the document that are known to be schemas.
  # Schema#subschema and Schema#resource_root_subschema are the intended mechanisms to instantiate subschemas
  # and resolve references. #[] and #jsi_root_node are not implemented.
  #
  # BootstrapSchema does not support mutation; its document must be immutable.
  #
  # @api private
  class MetaSchemaNode::BootstrapSchema
    include(Util::FingerprintHash::Immutable)
    include Schema::SchemaAncestorNode
    include Schema
    include(Util::Pretty)

    # @param jsi_ptr [JSI::Ptr] pointer to the schema in the document
    # @param jsi_document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(
        dialect: ,
        jsi_document: ,
        jsi_ptr: Ptr[],
        jsi_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY,
        jsi_schema_dynamic_anchor_map: Schema::DynamicAnchorMap::EMPTY,
        jsi_registry: nil
    )
      @dialect = dialect
      #chkbug fail(Bug) unless jsi_ptr.resolve_against(jsi_document).equal?(jsi_ptr)
      @jsi_ptr = jsi_ptr
      @jsi_document = jsi_document
      self.jsi_base_uri = jsi_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors
      self.jsi_schema_dynamic_anchor_map = jsi_schema_dynamic_anchor_map
      @jsi_registry = jsi_registry

      @memos = {}
      @jsi_node_content = jsi_ptr.evaluate(jsi_document)

      super()
    end

    # @return [Schema::Dialect]
    attr_reader(:dialect)

    # document containing the schema content
    attr_reader :jsi_document

    # JSI::Ptr pointing to this schema within the document
    attr_reader :jsi_ptr

    # @return [nil]
    def jsi_root_uri
    end

    # @return [Registry, nil]
    attr_reader(:jsi_registry)

    attr_reader(:jsi_node_content)

    # overrides {Schema#subschema}
    def subschema(subptr)
      subptr = Ptr.ary_ptr(subptr).resolve_against(jsi_node_content)
      kw = {
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr + subptr,
        jsi_base_uri: jsi_next_base_uri,
        jsi_schema_resource_ancestors: jsi_subschema_resource_ancestors,
        jsi_registry: jsi_registry,
      }
      # determine if subschema is a resource root here, for dynamic_anchor_map.
      # done in the same manner as Base#jsi_child_dynamic_anchor_map, when child is a schema - a bootstrap schema is instantiated
      # to check #jsi_is_resource_root?. here, though, that bootstrap schema is usually the returned subschema.
      subschema = dialect.bootstrap_schema(**kw,
        jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
      )
      if subschema.jsi_is_resource_root?
        # if subschema is a resource root, it should have our jsi_next_schema_dynamic_anchor_map
        subschema = dialect.bootstrap_schema(**kw,
          jsi_schema_dynamic_anchor_map: jsi_next_schema_dynamic_anchor_map.without_node(self, ptr: jsi_ptr + subptr),
        )
      end
      subschema
    end

    # overrides {Schema#resource_root_subschema}
    def resource_root_subschema(ptr)
      ptr = Ptr.ary_ptr(ptr)
      if jsi_resource_root
        curschema = jsi_resource_root
        remptr = ptr.resolve_against(jsi_resource_root.jsi_node_content)
        found = true
        while found
          return(curschema) if remptr.empty?
          found = false
          curschema.each_immediate_subschema_ptr do |subptr|
            if subptr.ancestor_of?(remptr)
              curschema = curschema.subschema(subptr)
              remptr = remptr.relative_to(subptr)
              found = true
              break
            end
          end
        end
        # ptr indicates a location where no element indicates a subschema.
        # TODO rm support (along with reinstantiate_as) and raise(NotASchemaError) here.
        return(curschema.subschema(remptr))
      end
      # no jsi_resource_root means the root is not a schema and no parent schema has an absolute uri.
      # result schema is instantiated relative to document root.
      dialect.bootstrap_schema(
        jsi_document: jsi_document,
        jsi_ptr: ptr.resolve_against(jsi_document),
        jsi_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY,
        jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
        jsi_registry: jsi_registry,
      )
    end

    # @private
    # @param dynamic_anchor_map [Schema::DynamicAnchorMap]
    # @return [MetaSchemaNode::BootstrapSchema]
    def jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
      return(self) if dynamic_anchor_map == jsi_schema_dynamic_anchor_map
      new_dynamic_anchor_map = dynamic_anchor_map.without_node(jsi_resource_root) if jsi_resource_root
      return(self) if new_dynamic_anchor_map == jsi_schema_dynamic_anchor_map

      dialect.bootstrap_schema(
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        jsi_base_uri: jsi_base_uri,
        jsi_schema_resource_ancestors: jsi_schema_resource_ancestors,
        jsi_schema_dynamic_anchor_map: new_dynamic_anchor_map,
        jsi_registry: jsi_registry,
      )
    end

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      jsi_pp_object_group(q, jsi_object_group_text) do
          q.pp schema_content
      end
    end

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      [
        self.class.name || MetaSchemaNode::BootstrapSchema.name,
        dialect.id ? -"(#{dialect.id})" : nil,
        !jsi_schema_dynamic_anchor_map.empty? ? jsi_schema_dynamic_anchor_map.anchor_schemas_identifier : nil,
        jsi_ptr.uri,
      ].compact.freeze
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: self.class,
        dialect: dialect,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
        jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
        jsi_registry: jsi_registry,
      }.freeze
    end

    private

    def jsi_memomap_class
      Util::MemoMap::Immutable
    end
  end
end
