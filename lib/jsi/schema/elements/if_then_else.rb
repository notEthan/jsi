# frozen_string_literal: true

module JSI
  module Schema::Elements
    IF_THEN_ELSE = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('if')
        if subschema(['if']).instance_valid?(instance)
          if keyword?('then')
            subschema(['then']).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
          end
        else
          if keyword?('else')
            subschema(['else']).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
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

            merge_schema_issues(if_result)

            if if_result.valid?
              if keyword?('then')
                then_result = inplace_subschema_validate(['then'])
                validate(
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
                validate(
                  else_result.valid?,
                  'validation.keyword.else.invalid',
                  "instance is not valid against `else` schema after not validating against `if` schema",
                  keyword: 'if',
                  results: [else_result],
                )
              end
            end
          else
            if keyword?('then')
              schema_warning('`then` has no effect without adjacent `if` keyword', 'then')
            end
            if keyword?('else')
              schema_warning('`else` has no effect without adjacent `if` keyword', 'else')
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # IF_THEN_ELSE = element_map
  end # module Schema::Elements
end
