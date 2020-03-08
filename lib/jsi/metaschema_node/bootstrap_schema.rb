# frozen_string_literal: true

module JSI
  # @private
  # internal class to bootstrap a metaschema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  # metaschema instance modules are attached to generated subclasses of BootstrapSchema by
  # {SchemaClasses.bootstrap_schema_class}. that subclass is instantiated with a document and
  # pointer, representing a schema.
  class MetaschemaNode::BootstrapSchema
    include Util::Memoize
    include Util::FingerprintHash

    # @param jsi_ptr [JSI::JSON::Pointer] pointer to the schema in the document
    # @param jsi_document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(
        jsi_document,
        jsi_ptr: JSI::JSON::Pointer[]
    )
      unless jsi_ptr.is_a?(JSI::JSON::Pointer)
        raise(TypeError, "jsi_ptr is not a JSI::JSON::Pointer: #{jsi_ptr.inspect}")
      end
      @jsi_ptr = jsi_ptr
      @jsi_document = jsi_document
    end

    # document containing the schema content
    attr_reader :jsi_document

    # JSI::JSON::Pointer pointing to this schema within the document
    attr_reader :jsi_ptr

    def jsi_node_content
      jsi_ptr.evaluate(jsi_document)
    end

    # @private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
      }
    end
  end
end
