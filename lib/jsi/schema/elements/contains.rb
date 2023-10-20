# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Contains
    # @private
    def internal_applicate_contains(idx, instance, &block)
    if instance.respond_to?(:to_ary)
      if keyword?('contains')
        contains_schema = subschema(['contains'])

        child_idx_valid = Hash.new { |h, i| h[i] = contains_schema.instance_valid?(instance[i]) }

        if child_idx_valid[idx]
          yield contains_schema
        else
          instance_valid = instance.each_index.any? { |i| child_idx_valid[i] }

          unless instance_valid
            # invalid application: if contains_schema does not validate against any child, it applies to every child
            yield contains_schema
          end
        end
      end
    end # if instance.respond_to?(:to_ary)
    end
  end
end
