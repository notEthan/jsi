# frozen_string_literal: true

module JSI
  module Schema::Elements
    IF_THEN_ELSE = element_map do
      Schema::Element.new do |element|
        element.add_action(:subschema) do
          if keyword?('if')
            #> This keyword's value MUST be a valid JSON Schema.
            cxt_yield(['if'])
          end

          if keyword?('then')
            #> This keyword's value MUST be a valid JSON Schema.
            cxt_yield(['then'])
          end

          if keyword?('else')
            #> This keyword's value MUST be a valid JSON Schema.
            cxt_yield(['else'])
          end
        end # element.add_action(:subschema)

        element.add_action(:inplace_applicate) do
      if keyword?('if')
        if subschema(['if']).instance_valid?(instance)
          if collect_evaluated
            inplace_subschema_applicate(['if'], applicate: false)
          end
          if keyword?('then')
            inplace_subschema_applicate(['then'])
          end
        else
          if keyword?('else')
            inplace_subschema_applicate(['else'])
          end
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
          if keyword?('if')
            # This keyword's value MUST be a valid JSON Schema.
            # This validation outcome of this keyword's subschema has no direct effect on the overall validation
            # result. Rather, it controls which of the "then" or "else" keywords are evaluated.
            if_result = inplace_subschema_validate(['if'])

            if if_result.valid?
              result.evaluated_tokens.merge(if_result.evaluated_tokens)
            end

            if if_result.valid?
              if keyword?('then')
                then_result = inplace_subschema_validate(['then'])
                inplace_results_validate(
                  then_result.valid?,
                  'validation.keyword.then.invalid',
                  "instance is not valid against `then` schema after validating against `if` schema",
                  keyword: 'if',
                  results: [then_result],
                )
              end
            else
              if keyword?('else')
                else_result = inplace_subschema_validate(['else'])
                inplace_results_validate(
                  else_result.valid?,
                  'validation.keyword.else.invalid',
                  "instance is not valid against `else` schema after not validating against `if` schema",
                  keyword: 'if',
                  results: [else_result],
                )
              end
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # IF_THEN_ELSE = element_map
  end # module Schema::Elements
end
