# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    # returns a set of subschemas of this schema for the given property name, from keywords
    #   `properties`, `patternProperties`, and `additionalProperties`.
    #
    # @param property_name [String] the property name for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given property_name
    def subschemas_for_property_name(property_name)
      begin
        ptr = self
        schema = ptr.evaluate(document)
        Set.new.tap do |ptrs|
          if schema.respond_to?(:to_hash)
            apply_additional = true
            if schema.key?('properties') && schema['properties'].respond_to?(:to_hash) && schema['properties'].key?(property_name)
              apply_additional = false
              ptrs << ptr['properties'][property_name]
            end
            if schema['patternProperties'].respond_to?(:to_hash)
              schema['patternProperties'].each_key do |pattern|
                if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  ptrs << ptr['patternProperties'][pattern]
                end
              end
            end
            if apply_additional && schema.key?('additionalProperties')
              ptrs << ptr['additionalProperties']
            end
          end
        end
      end
    end

    # returns a set of subschemas of this schema for the given array index, from keywords
    #   `items` and `additionalItems`.
    #
    # @param index [Integer] the array index for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given array index
    def subschemas_for_index(index)
      begin
        ptr = self
        schema = ptr.evaluate(document)
        Set.new.tap do |ptrs|
          if schema.respond_to?(:to_hash)
            if schema['items'].respond_to?(:to_ary)
              if schema['items'].each_index.to_a.include?(idx)
                ptrs << ptr['items'][idx]
              elsif schema.key?('additionalItems')
                ptrs << ptr['additionalItems']
              end
            elsif schema.key?('items')
              ptrs << ptr['items']
            end
          end
        end
      end
    end
  end
end
