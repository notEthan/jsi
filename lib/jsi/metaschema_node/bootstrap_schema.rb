# frozen_string_literal: true

module JSI
  # internal class to bootstrap a meta-schema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  #
  # this class is to only be instantiated on nodes in the document that are known to be schemas.
  # Schema#subschema and Schema#resource_root_subschema are the intended mechanisms to instantiate subschemas
  # and resolve references. #[] and #jsi_root_node are not implemented.
  #
  # schema implementation modules are included on generated subclasses of BootstrapSchema by
  # {SchemaClasses.bootstrap_schema_class}. that subclass is instantiated with a document and
  # pointer, representing a schema.
  #
  # BootstrapSchema does not support mutation; its document must be immutable.
  #
  # @api private
  class MetaSchemaNode::BootstrapSchema
    include Util::FingerprintHash
    include Schema::SchemaAncestorNode
    include Schema

    class << self
      def inspect
        if self == MetaSchemaNode::BootstrapSchema
          name.freeze
        else
          -"#{name || MetaSchemaNode::BootstrapSchema.name} (#{schema_implementation_modules.map(&:inspect).join(', ')})"
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
        jsi_schema_base_uri: nil
    )
      raise(Bug, "no #schema_implementation_modules") unless respond_to?(:schema_implementation_modules)

      self.jsi_ptr = jsi_ptr
      self.jsi_document = jsi_document
      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = Util::EMPTY_ARY

      @jsi_node_content = jsi_ptr.evaluate(jsi_document)
      #chkbug raise(Bug, 'BootstrapSchema instance must be frozen') unless jsi_node_content.frozen?

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
      )
    end

    # overrides {Schema#resource_root_subschema}
    def resource_root_subschema(ptr)
      # BootstrapSchema does not track jsi_schema_resource_ancestors used by Schema#schema_resource_root;
      # resource_root_subschema is always relative to the document root.
      # BootstrapSchema also does not implement jsi_root_node or #[]. we instantiate the ptr directly
      # rather than as a subschema from the root.
      self.class.new(
        jsi_document,
        jsi_ptr: Ptr.ary_ptr(ptr),
        jsi_schema_base_uri: nil,
      )
    end

    # @return [String]
    def inspect
      -"\#<#{jsi_object_group_text.join(' ')} #{schema_content.inspect}>"
    end

    def to_s
      inspect
    end

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text jsi_object_group_text.join(' ')
      q.group(2) {
          q.breakable ' '
          q.pp schema_content
      }
      q.breakable ''
      q.text '>'
    end

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      [
        self.class.name || MetaSchemaNode::BootstrapSchema.name,
        -"(#{schema_implementation_modules.map(&:inspect).join(', ')})",
        jsi_ptr.uri,
      ].freeze
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
      }.freeze
    end

    private

    def jsi_memomap_class
      Util::MemoMap::Immutable
    end
  end
end
