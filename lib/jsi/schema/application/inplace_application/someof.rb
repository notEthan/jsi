# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::SomeOf
    # @private
    def internal_applicate_someOf(instance, visited_refs, &block)
      if schema_content['allOf'].respond_to?(:to_ary)
        schema_content['allOf'].each_index do |i|
          subschema(['allOf', i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
      if schema_content['anyOf'].respond_to?(:to_ary)
        schema_content['anyOf'].each_index do |i|
          if subschema(['anyOf', i]).validate_instance(instance)
            subschema(['anyOf', i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
          end
        end
      end
      if schema_content['oneOf'].respond_to?(:to_ary)
        one_i = schema_content['oneOf'].each_index.detect do |i|
          subschema(['oneOf', i]).validate_instance(instance)
        end
        if one_i
          subschema(['oneOf', one_i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
    end
  end
end
