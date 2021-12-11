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
      end # Schema::Element.new
    end # IF_THEN_ELSE = element_map
  end # module Schema::Elements
end
