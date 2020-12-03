# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    # returns a set of subschemas of this schema for the given property name, from keywords
    #   `properties`, `patternProperties`, and `additionalProperties`.
    #
    # @param property_name [String] the property name for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given property_name
    def subschemas_for_property_name(property_name)
      jsi_memoize(:subschemas_for_property_name, property_name) do |property_name|
        jsi_ptr.schema_subschema_ptrs_for_property_name(jsi_document, property_name).map do |ptr|
          resource_root_subschema(ptr)
        end.to_set
      end
    end

    # returns a set of subschemas of this schema for the given array index, from keywords
    #   `items` and `additionalItems`.
    #
    # @param index [Integer] the array index for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given array index
    def subschemas_for_index(index)
      jsi_memoize(:subschemas_for_index, index) do |index|
        jsi_ptr.schema_subschema_ptrs_for_index(jsi_document, index).map do |ptr|
          resource_root_subschema(ptr)
        end.to_set
      end
    end
  end
end
