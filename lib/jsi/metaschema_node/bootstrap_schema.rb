# frozen_string_literal: true

module JSI
  # internal class to bootstrap a meta-schema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  #
  # this class is to only be instantiated on nodes in the document that are known to be schemas.
  # Schema#subschema and Schema#resource_root_subschema are the intended mechanisms to instantiate subschemas
  # and resolve references. #[] and #jsi_root_node are not implemented.
  #
  # #dialect is defined on generated subclasses of BootstrapSchema by
  # {Schema::Dialect#bootstrap_schema_class}. that subclass is instantiated with a document and
  # pointer, representing a schema.
  #
  # BootstrapSchema does not support mutation; its document must be immutable.
  #
  # @api private
  class MetaSchemaNode::BootstrapSchema
    include(Util::FingerprintHash::Immutable)
    include Schema::SchemaAncestorNode
    include Schema
    include(Util::Pretty)

    class << self
      def inspect
        if self == MetaSchemaNode::BootstrapSchema
          name.freeze
        else
          -"#{name || MetaSchemaNode::BootstrapSchema.name} (#{described_dialect})"
        end
      end

      def to_s
        inspect
      end
    end

    # @param jsi_ptr [JSI::Ptr] pointer to the schema in the document
    # @param jsi_document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(
        jsi_document,
        jsi_ptr: Ptr[],
        jsi_schema_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY,
        jsi_schema_dynamic_anchor_map: Schema::DynamicAnchorMap::EMPTY,
        jsi_schema_registry: nil
    )
      fail(Bug, "no #dialect") unless respond_to?(:dialect)

      self.jsi_ptr = jsi_ptr
      self.jsi_document = jsi_document
      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors
      self.jsi_schema_dynamic_anchor_map = jsi_schema_dynamic_anchor_map
      self.jsi_schema_registry = jsi_schema_registry

      @jsi_node_content = jsi_ptr.evaluate(jsi_document)
      #chkbug fail(Bug, 'BootstrapSchema instance must be frozen') unless jsi_node_content.frozen?

      super()
    end

    # document containing the schema content
    attr_reader :jsi_document

    # JSI::Ptr pointing to this schema within the document
    attr_reader :jsi_ptr

    attr_reader(:jsi_node_content)

    # overrides {Schema#subschema}
    def subschema(subptr)
      self.class.new(
        jsi_document,
        jsi_ptr: jsi_ptr + subptr,
        jsi_schema_base_uri: jsi_resource_ancestor_uri,
        jsi_schema_resource_ancestors: jsi_subschema_resource_ancestors,
        jsi_schema_registry: jsi_schema_registry,
      )
    end

    # overrides {Schema#resource_root_subschema}
    def resource_root_subschema(ptr)
      ptr = Ptr.ary_ptr(ptr)
      if schema_resource_root
        curschema = schema_resource_root
        remptr = ptr.resolve_against(schema_resource_root.jsi_node_content)
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
      # no schema_resource_root means the root is not a schema and no parent schema has an absolute uri.
      # result schema is instantiated relative to document root.
      self.class.new(
        jsi_document,
        jsi_ptr: ptr,
        jsi_schema_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY,
        jsi_schema_registry: jsi_schema_registry,
      )
    end

    # @return [MetaschemaNode::BootstrapSchema, nil]
    def schema_resource_root
      jsi_subschema_resource_ancestors.last
    end

    # @private
    # @param dynamic_anchor_map [Schema::DynamicAnchorMap]
    # @return [MetaSchemaNode::BootstrapSchema]
    def jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
      return(self) if dynamic_anchor_map == jsi_schema_dynamic_anchor_map

      self.class.new(
        jsi_document,
        jsi_ptr: jsi_ptr,
        jsi_schema_base_uri: jsi_schema_base_uri,
        jsi_schema_resource_ancestors: jsi_schema_resource_ancestors,
        jsi_schema_dynamic_anchor_map: dynamic_anchor_map,
        jsi_schema_registry: jsi_schema_registry,
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
        jsi_ptr.uri,
      ].compact.freeze
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
        jsi_schema_dynamic_anchor_map: jsi_schema_dynamic_anchor_map,
        jsi_schema_registry: jsi_schema_registry,
      }.freeze
    end

    private

    def jsi_memomap_class
      Util::MemoMap::Immutable
    end
  end
end
