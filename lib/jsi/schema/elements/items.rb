# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_ary)
      if keyword?('items') && schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].each_index.to_a.include?(token)
          cxt_yield(subschema(['items', token]))
        elsif keyword?('additionalItems')
          cxt_yield(subschema(['additionalItems']))
        end
      elsif keyword?('items')
        cxt_yield(subschema(['items']))
      end
    end # if instance.respond_to?(:to_ary)
        end # element.add_action(:child_applicate)
      end # Schema::Element.new
    end # ITEMS = element_map
  end # module Schema::Elements
end
