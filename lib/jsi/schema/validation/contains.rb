# frozen_string_literal: true

module JSI
  module Schema::Validation::Contains
    # @private
    def internal_validate_contains(result_builder)
      if schema_content.key?('contains')
        # An array instance is valid against "contains" if at least one of its elements is valid against
        # the given schema.
        if result_builder.instance.respond_to?(:to_ary)
          results = result_builder.instance.each_index.map do |i|
            result_builder.child_subschema_validate(['contains'], [i])
          end
          result_builder.validate(
            results.any?(&:valid?),
            'instance array does not contain any items valid against `contains` schema value',
            keyword: 'contains',
            results: results,
          )
        end
      end
    end
  end
end
