# frozen_string_literal: true

module JSI
  # @private
  # internal class to bootstrap a metaschema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  #
  # this class is to only be instantiated on nodes in the document that are known to be schemas.
  # Schema#subschema and Schema#resource_root_subschema are the intended mechanisms to instantiate subschemas
  # and resolve references. #[] and #jsi_root_node are not implemented.
  #
  # metaschema instance modules are attached to generated subclasses of BootstrapSchema by
  # {SchemaClasses.bootstrap_schema_class}. that subclass is instantiated with a document and
  # pointer, representing a schema.
  class MetaschemaNode::BootstrapSchema
    include Util::Memoize
    include Util::FingerprintHash
    include Schema::SchemaAncestorNode

    class << self
      def inspect
        if self == MetaschemaNode::BootstrapSchema
          name
        else
          "#{name || MetaschemaNode::BootstrapSchema.name} (#{metaschema_instance_modules.map(&:inspect).join(', ')})"
        end
      end

      alias_method :to_s, :inspect
    end

    # @param jsi_ptr [JSI::JSON::Pointer] pointer to the schema in the document
    # @param jsi_document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(
        jsi_document,
        jsi_ptr: JSI::JSON::Pointer[]
    )
      unless respond_to?(:metaschema_instance_modules)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #metaschema_instance_modules")
      end
      self.jsi_ptr = jsi_ptr
      self.jsi_document = jsi_document
    end

    # document containing the schema content
    attr_reader :jsi_document

    # JSI::JSON::Pointer pointing to this schema within the document
    attr_reader :jsi_ptr

    def jsi_node_content
      jsi_ptr.evaluate(jsi_document)
    end

    # @return [String]
    def inspect
      "\#<#{object_group_text.join(' ')} #{schema_content.inspect}>"
    end

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text object_group_text.join(' ')
      q.group_sub {
        q.nest(2) {
          q.breakable ' '
          q.pp schema_content
        }
      }
      q.breakable ''
      q.text '>'
    end

    # @private
    # @return [Array<String>]
    def object_group_text
      [
        self.class.name || MetaschemaNode::BootstrapSchema.name,
        "(#{metaschema_instance_modules.map(&:inspect).join(', ')})",
        jsi_ptr.uri,
      ]
    end

    # @private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
        metaschema_instance_modules: metaschema_instance_modules,
      }
    end
  end
end
