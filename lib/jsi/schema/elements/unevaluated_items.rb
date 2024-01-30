# frozen_string_literal: true

module JSI
  module Schema::Elements
    # https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-01#name-unevaluateditems
    UNEVALUATED_ITEMS = element_map do
      Schema::Element.new(keyword: 'unevaluatedItems') do |element|
        element.add_action(:application_requires_evaluated) { cxt_yield(true) if keyword?('unevaluatedItems') }

        element.add_action(:subschema) do
          #> The value of "unevaluatedItems" MUST be a valid JSON Schema.
          if keyword?('unevaluatedItems')
            cxt_yield(['unevaluatedItems'])
          end
        end

        element.add_action(:validate) do
          next if !keyword?('unevaluatedItems')
          next if !instance.respond_to?(:to_ary)
          results = {}
          instance.each_index do |i|
            if !result.evaluated_tokens.include?(i)
              results[i] = child_subschema_validate(i, ['unevaluatedItems'])
            end
          end

          child_results_validate(
            results.each_value.all?(&:valid?),
            'validation.keyword.unevaluatedItems.invalid',
            "instance array unevaluated items are not all valid against `unevaluatedItems` schema",
            keyword: 'unevaluatedItems',
            child_results: results,
            instance_indexes_valid: results.inject({}) { |h, (i, r)| h.update({i => r.valid?}) }.freeze,
          )
        end
      end
    end
  end
end
