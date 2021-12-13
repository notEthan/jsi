# frozen_string_literal: true

module JSI
  module Schema::Elements
    SELF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
          cxt_yield(schema)
        end
      end
    end
  end
end
