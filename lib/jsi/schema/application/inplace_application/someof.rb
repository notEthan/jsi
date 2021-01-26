# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::SomeOf
    # @private
    def internal_applicate_someOf(instance, visited_refs, &block)
      if keyword?('allOf') && schema_content['allOf'].respond_to?(:to_ary)
        schema_content['allOf'].each_index do |i|
          subschema(['allOf', i]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
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
      if keyword?('oneOf') && schema_content['oneOf'].respond_to?(:to_ary)
        oneOf = schema_content['oneOf'].each_index.map { |i| subschema(['oneOf', i]) }
        validOf = oneOf.select { |schema| schema.instance_valid?(instance) }
        if validOf.size == 1
          applicators = validOf
        else
          # invalid application: if none or multiple of the oneOf were valid, we apply them all
          applicators = oneOf
        end

        applicators.each do |applicator|
          applicator.each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
        end
      end
    end
  end
end
