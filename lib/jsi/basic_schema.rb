# frozen_string_literal: true

module JSI
  class BasicSchema
    include Util::Memoize
    include Util::FingerprintHash

    # @param ptr [JSI::JSON::Pointer] pointer to the schema in the document
    # @param document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(ptr, document)
      unless ptr.is_a?(JSI::JSON::Pointer)
        raise(TypeError, "ptr is not a JSI::JSON::Pointer: #{ptr.inspect}")
      end
      @ptr = ptr
      @document = document

      @schema_content = ptr.evaluate(document)
    end

    # document containing the schema content
    attr_reader :document

    # JSI::JSON::Pointer pointing to this schema within the document
    attr_reader :ptr

    # underlying schema content (boolean or ruby Hash / json object)
    attr_reader :schema_content

    # returns a subschema of this BasicSchema
    #
    # @param *tokens [Array[Object]] tokens appended to our ptr indicating the location of the subschema
    # @return [JSI::BasicSchema] the subschema at the location indicated by *tokens
    def [](*tokens)
      self.class.new(ptr + JSI::JSON::Pointer[*tokens], document)
    end

    # returns a schema in the same document as this one at the given ptr
    # @param ptr [JSI::JSON::Pointer] pointer to a schema in our document
    # @return [JSI::BasicSchema] the schema in our document at the given pointer
    def /(ptr)
      if ptr.respond_to?(:to_ary)
        ptr = JSI::JSON::Pointer[*ptr]
      end
      self.class.new(ptr, document)
    end

    # @return [String]
    def inspect
      "\#<#{object_group_text.join(' ')} #{schema_content.inspect}>"
    end

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
        self.class.inspect,
        ptr.uri,
      ]
    end

    # @private
    def jsi_fingerprint
      {class: self.class, ptr: @ptr, document: @document}
    end
  end
end
