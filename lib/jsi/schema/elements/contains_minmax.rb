# frozen_string_literal: true

module JSI
  module Schema::Elements
    CONTAINS_MINMAX = element_map do
      Schema::Element.new(keywords: ['contains', 'minContains', 'maxContains']) do |element|
        element.add_action(:subschema) do
          if keyword?('contains')
            #> The value of this keyword MUST be a valid JSON Schema.
            cxt_yield(['contains'])
          end
        end # element.add_action(:subschema)

        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_ary)
      if keyword?('contains')
        contains_schema = subschema(['contains'])

        child_idx_valid = Hash.new { |h, i| h[i] = contains_schema.instance_valid?(instance[i]) }

        if child_idx_valid[token]
          child_schema_applicate(contains_schema)
        else
          minContains = keyword_value_numeric?('minContains') ? schema_content['minContains'] : 1
          child_valid_count = instance.each_index.inject(0) { |n, i| n < minContains && child_idx_valid[i] ? n + 1 : n }

          if child_valid_count < minContains
            # invalid application: if contains_schema does not validate against `minContains` children,
            # it applies to every child.
            # note: this does not consider maxContains; a validation error from maxContains is not from any
            # validation error of child application (which invalid application is intended to preserve), but
            # rather from too few failures in child application. children that don't validate against contains
            # are correctly not described by contains when contains validation failure comes from maxContains.
            child_schema_applicate(contains_schema)
          end
        end
      end
    end # if instance.respond_to?(:to_ary)
        end # element.add_action(:child_applicate)

        element.add_action(:validate) do
          if keyword?('contains')
            # An array instance is valid against "contains" if at least one of its elements is valid against
            # the given schema.
            if instance.respond_to?(:to_ary)
              results = {}
              instance.each_index do |i|
                results[i] = child_subschema_validate(i, ['contains'])
              end
              child_results_validate(
                results.each_value.any?(&:valid?),
                'validation.keyword.contains.none',
                "instance array does not contain any items valid against `contains` schema",
                keyword: 'contains',
                child_results: results,
                # when invalid these are all false, but included for consistency with `contains` with min/max
                instance_indexes_valid: results.inject({}) { |h, (i, r)| h.update({i => r.valid?}) }.freeze,
              )
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # CONTAINS_MINMAX = element_map
  end # module Schema::Elements
end
