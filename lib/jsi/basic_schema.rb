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

    # returns a set of subschemas of this schema for the given property name.
    #
    # @param property_name [Object] the property name for which to find subschemas
    # @return [Set<JSI::BasicSchema>] subschemas
    def subschemas_for_property_name(property_name)
      jsi_memoize(__method__, property_name) do |property_name|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            apply_additional = true
            if schema_content.key?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(property_name)
              apply_additional = false
              subschemas << self['properties', property_name]
            end
            if schema_content['patternProperties'].respond_to?(:to_hash)
              schema_content['patternProperties'].each_key do |pattern|
                if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  subschemas << self['patternProperties', pattern]
                end
              end
            end
            if apply_additional && schema_content.key?('additionalProperties')
              subschemas << self['additionalProperties']
            end
          end
        end
      end
    end

    # returns a set of subschemas of this schema for the given array index.
    #
    # @param idx [Object] the array index for which to find subschemas
    # @return [Set<JSI::BasicSchema>] subschemas
    def subschemas_for_index(idx)
      jsi_memoize(__method__, idx) do |idx|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            if schema_content['items'].respond_to?(:to_ary)
              if schema_content['items'].each_index.to_a.include?(idx)
                subschemas << self['items', idx]
              elsif schema_content.key?('additionalItems')
                subschemas << self['additionalItems']
              end
            elsif schema_content.key?('items')
              subschemas << self['items']
            end
          end
        end
      end
    end

    # returns any applicator subschemas of this schema ($ref, oneOf, anyOf, allOf) which apply to the given instance
    #
    # @param instance [Object] the instance to check any applicators against
    # @return [Set<JSI::BasicSchema>] matched applicator subschemas
    def match_to_instance(instance)
      Set.new.tap do |schemas|
        if schema_content.respond_to?(:to_hash)
          if schema_content['$ref'].respond_to?(:to_str)
            ptr.deref(document) do |deref_ptr|
              schemas.merge((self / deref_ptr).match_to_instance(instance))
            end
          else
            schemas << self
          end
          if schema_content['allOf'].respond_to?(:to_ary)
            schema_content['allOf'].each_index do |i|
              schemas.merge(self['allOf', i].match_to_instance(instance))
            end
          end
          if schema_content['anyOf'].respond_to?(:to_ary)
            schema_content['anyOf'].each_index do |i|
              valid = ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['anyOf'][i].fragment)
              if valid
                schemas.merge(self['anyOf', i].match_to_instance(instance))
              end
            end
          end
          if schema_content['oneOf'].respond_to?(:to_ary)
            one_i = schema_content['oneOf'].each_index.detect do |i|
              ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['oneOf'][i].fragment)
            end
            if one_i
              schemas.merge(self['oneOf', one_i].match_to_instance(instance))
            end
          end
          # TODO dependencies
        else
          schemas << self
        end
      end
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
