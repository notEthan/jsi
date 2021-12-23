# frozen_string_literal: true

module JSI
  module Schema::Elements
    ALL_OF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('allOf') && schema_content['allOf'].respond_to?(:to_ary)
        schema_content['allOf'].each_index do |i|
          subschema(['allOf', i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
          if keyword?('allOf')
            value = schema_content['allOf']
            # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
            if value.respond_to?(:to_ary)
              # An instance validates successfully against this keyword if it validates successfully against all
              # schemas defined by this keyword's value.
              allOf_results = value.each_index.map do |i|
                inplace_subschema_validate(['allOf', i])
              end
              validate(
                allOf_results.all?(&:valid?),
                "instance is not valid against all `allOf` schemas",
                keyword: 'allOf',
                results: allOf_results,
              )
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ALL_OF = element_map
  end # module Schema::Elements

  module Schema::Elements
    ANY_OF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('anyOf') && schema_content['anyOf'].respond_to?(:to_ary)
        anyOf = schema_content['anyOf'].each_index.map { |i| subschema(['anyOf', i]) }
        validOf = anyOf.select { |schema| schema.instance_valid?(instance) }
        if !validOf.empty?
          applicators = validOf
        else
          # invalid application: if none of the anyOf were valid, we apply them all
          applicators = anyOf
        end

        applicators.each do |applicator|
          applicator.each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
          if keyword?('anyOf')
            value = schema_content['anyOf']
            # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
            if value.respond_to?(:to_ary)
              # An instance validates successfully against this keyword if it validates successfully against at
              # least one schema defined by this keyword's value.
              # Note that when annotations are being collected, all subschemas MUST be examined so that
              # annotations are collected from each subschema that validates successfully.
              anyOf_results = value.each_index.map do |i|
                inplace_subschema_validate(['anyOf', i])
              end
              validate(
                anyOf_results.any?(&:valid?),
                "instance is not valid against any `anyOf` schema",
                keyword: 'anyOf',
                results: anyOf_results,
              )
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ANY_OF = element_map
  end # module Schema::Elements

  module Schema::Elements
    ONE_OF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('oneOf') && schema_content['oneOf'].respond_to?(:to_ary)
        oneOf_idxs = schema_content['oneOf'].each_index
        subschema_idx_valid = Hash.new { |h, i| h[i] = subschema(['oneOf', i]).instance_valid?(instance) }
        # count up to 2 `oneOf` subschemas which `instance` validates against
        nvalid = oneOf_idxs.inject(0) { |n, i| n <= 1 && subschema_idx_valid[i] ? n + 1 : n }
        if nvalid == 1
          applicator_idxs = oneOf_idxs.select { |i| subschema_idx_valid[i] }
        else
          # invalid application: if none or multiple of the oneOf were valid, we apply them all
          applicator_idxs = oneOf_idxs
        end

        applicator_idxs.each do |i|
          subschema(['oneOf', i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
          if keyword?('oneOf')
            value = schema_content['oneOf']
            # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
            if value.respond_to?(:to_ary)
              # An instance validates successfully against this keyword if it validates successfully against
              # exactly one schema defined by this keyword's value.
              oneOf_results = value.each_index.map do |i|
                inplace_subschema_validate(['oneOf', i])
              end
              if oneOf_results.none?(&:valid?)
                validate(
                  false,
                  "instance is not valid against any `oneOf` schema",
                  keyword: 'oneOf',
                  results: oneOf_results,
                )
              else
                # TODO better info on what schemas passed/failed validation
                validate(
                  oneOf_results.select(&:valid?).size == 1,
                  "instance is valid against multiple `oneOf` schemas",
                  keyword: 'oneOf',
                  results: oneOf_results,
                )
              end
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ONE_OF = element_map
  end # module Schema::Elements
end
