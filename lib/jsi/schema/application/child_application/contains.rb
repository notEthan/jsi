# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Contains
    # @private
    def internal_applicate_contains(idx, instance, &block)
      if keyword?('contains')
        contains_schema = subschema(['contains'])

        child_idx_valid = {}
        instance.each_index do |i|
          child_idx_valid[i] = contains_schema.instance_valid?(instance[i])
        end

        if child_idx_valid[idx]
          yield contains_schema
        else
          instance_valid = child_idx_valid.values.any? { |v| v }

          unless instance_valid
            # invalid application: if contains_schema does not validate against any child, it applies to every child
            yield contains_schema
          end
        end
      end
    end
  end
end
