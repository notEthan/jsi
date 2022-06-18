# frozen_string_literal: true

module JSI
  # internal class to bootstrap a metaschema. represents a schema without the complexity of JSI::Base. the
  # schema is represented but schemas describing the schema are not.
  #
  # this class is to only be instantiated on nodes in the document that are known to be schemas.
  # Schema#subschema and Schema#resource_root_subschema are the intended mechanisms to instantiate subschemas
  # and resolve references. #[] and #jsi_root_node are not implemented.
  #
  # schema implementation modules are attached to generated subclasses of BootstrapSchema by
  # {SchemaClasses.bootstrap_schema_class}. that subclass is instantiated with a document and
  # pointer, representing a schema.
  #
  # @api private
  class MetaschemaNode::BootstrapSchema
    include Util::Memoize
    include Util::FingerprintHash
    include Schema::SchemaAncestorNode
    include Schema

    class << self
      def inspect
        if self == MetaschemaNode::BootstrapSchema
          name
        else
          "#{name || MetaschemaNode::BootstrapSchema.name} (#{schema_implementation_modules.map(&:inspect).join(', ')})"
        end
      end

      alias_method :to_s, :inspect
    end

    # @param jsi_ptr [JSI::Ptr] pointer to the schema in the document
    # @param jsi_document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(
        jsi_document,
        jsi_ptr: Ptr[],
        jsi_schema_base_uri: nil
    )
      raise(Bug, "no #schema_implementation_modules") unless respond_to?(:schema_implementation_modules)

      jsi_initialize_memos

      self.jsi_ptr = jsi_ptr
      self.jsi_document = jsi_document
      self.jsi_schema_base_uri = jsi_schema_base_uri
    end

    # document containing the schema content
    attr_reader :jsi_document

    # JSI::Ptr pointing to this schema within the document
    attr_reader :jsi_ptr

    def jsi_node_content
      jsi_ptr.evaluate(jsi_document)
    end

    # @return [String]
    def inspect
      "\#<#{jsi_object_group_text.join(' ')} #{schema_content.inspect}>"
    end

    alias_method :to_s, :inspect

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text jsi_object_group_text.join(' ')
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
    def jsi_object_group_text
      [
        self.class.name || MetaschemaNode::BootstrapSchema.name,
        "(#{schema_implementation_modules.map(&:inspect).join(', ')})",
        jsi_ptr.uri,
      ]
    end

    # @private
    def jsi_fingerprint
      {
        class: self.class,
        jsi_ptr: @jsi_ptr,
        jsi_document: @jsi_document,
        schema_implementation_modules: schema_implementation_modules,
      }
    end
  end
end
