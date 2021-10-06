# frozen_string_literal: true

module JSI
  module Schema::Validation::Type
    # @private
    def internal_validate_type(result_builder)
      if schema_content.key?('type')
        value = schema_content['type']
        instance = result_builder.instance
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
                result_builder.schema_error("`type` is not one of: null, boolean, object, array, string, number, or integer", 'type')
              end
            else
              result_builder.schema_error("`type` is not a string at index #{i}", 'type')
            end
          end
          result_builder.validate(
            matched_type,
            'instance type does not match `type` value',
            keyword: 'type',
          )
        else
          result_builder.schema_error('`type` is not a string or array', 'type')
        end
      end
    end
  end
end
