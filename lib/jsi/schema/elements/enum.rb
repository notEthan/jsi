# frozen_string_literal: true

module JSI
  module Schema::Elements
    ENUM = element_map do
      Schema::Element.new(keyword: 'enum') do |element|
        element.add_action(:validate) do
      if keyword?('enum')
        value = schema_content['enum']
        #> The value of this keyword MUST be an array.
        if value.respond_to?(:to_ary)
          # An instance validates successfully against this keyword if its value is equal to one of the
          # elements in this keyword's array value.
          validate(
            value.include?(instance),
            'validation.keyword.enum.none_equal',
            "instance is not equal to any `enum` item",
            keyword: 'enum',
          )
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ENUM = element_map
  end # module Schema::Elements
end
