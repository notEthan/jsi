# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    # returns a set of subschemas of this schema for the given property name, from keywords
    #   `properties`, `patternProperties`, and `additionalProperties`.
    #
    # @param property_name [String] the property name for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given property_name
    def subschemas_for_property_name(property_name)
      jsi_memoize(__method__, property_name) do |property_name|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            apply_additional = true
            if schema_content.key?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(property_name)
              apply_additional = false
              subschemas << subschema(['properties', property_name])
            end
            if schema_content['patternProperties'].respond_to?(:to_hash)
              schema_content['patternProperties'].each_key do |pattern|
                if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  subschemas << subschema(['patternProperties', pattern])
                end
              end
            end
            if apply_additional && schema_content.key?('additionalProperties')
              subschemas << subschema(['additionalProperties'])
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
      jsi_memoize(__method__, index) do |idx|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            if schema_content['items'].respond_to?(:to_ary)
              if schema_content['items'].each_index.to_a.include?(idx)
                subschemas << subschema(['items', idx])
              elsif schema_content.key?('additionalItems')
                subschemas << subschema(['additionalItems'])
              end
            elsif schema_content.key?('items')
              subschemas << subschema(['items'])
            end
          end
        end
      end
    end
  end
end
