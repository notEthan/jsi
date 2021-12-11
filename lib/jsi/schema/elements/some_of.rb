# frozen_string_literal: true

module JSI
  module Schema::Elements
    SOME_OF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
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
      end # Schema::Element.new
    end # SOME_OF = element_map
  end # module Schema::Elements
end
