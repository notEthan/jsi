# frozen_string_literal: true

module JSI
  module Schema::Elements
    TYPE = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('type')
        value = schema_content['type']
        # The value of this keyword MUST be either a string or an array. If it is an array, elements of
        # the array MUST be strings and MUST be unique.
        if value.respond_to?(:to_str) || value.respond_to?(:to_ary)
          types = value.respond_to?(:to_str) ? [value] : value
          matched_type = types.each_with_index.any? do |type, i|
            if type.respond_to?(:to_str)
              case type.to_str
              when 'null'
                instance == nil
              when 'boolean'
                instance == true || instance == false
              when 'object'
                instance.respond_to?(:to_hash)
              when 'array'
                instance.respond_to?(:to_ary)
              when 'string'
                instance.respond_to?(:to_str)
              when 'number'
                instance.is_a?(Numeric)
              when 'integer'
                internal_integer?(instance)
              else
                schema_error("`type` is not one of: null, boolean, object, array, string, number, or integer", 'type')
              end
            else
              schema_error("`type` is not a string at index #{i}", 'type')
            end
          end
          validate(
            matched_type,
            'instance type does not match `type` value',
            keyword: 'type',
          )
        else
          schema_error('`type` is not a string or array', 'type')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # TYPE = element_map
  end # module Schema::Elements
end
