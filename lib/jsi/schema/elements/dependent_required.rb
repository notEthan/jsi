# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENT_REQUIRED = element_map do
      Schema::Element.new(keyword: 'dependentRequired') do |element|
        element.add_action(:validate) do
          #> The value of this keyword MUST be an object.
          next if !keyword_value_hash?('dependentRequired')
          next if !instance.respond_to?(:to_hash)

          #> This keyword specifies properties that are required if a specific other property is
          #> present. Their requirement is dependent on the presence of the other property.
          #
          #> Validation succeeds if, for each name that appears in both the instance and as a name
          #> within this keyword's value, every item in the corresponding array is also the name of
          #> a property in the instance.
          missing_dependent_required = {}
          schema_content['dependentRequired'].each do |property_name, dependent_property_names|
            #> Properties in this object, if any, MUST be arrays.
            next if !dependent_property_names.respond_to?(:to_ary)
            if instance.key?(property_name)
              missing_required = dependent_property_names.reject { |name| instance.key?(name) }
              unless missing_required.empty?
                missing_dependent_required[property_name] = missing_required
              end
            end
          end
          validate(
            missing_dependent_required.empty?,
            'validation.keyword.dependentRequired.missing_property_names',
            "instance object does not contain all dependent required property names specified by `dependentRequired`",
            keyword: 'dependentRequired',
            missing_dependent_required: missing_dependent_required,
          )
        end
      end
    end
  end
end
