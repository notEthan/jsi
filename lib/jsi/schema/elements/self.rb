# frozen_string_literal: true

module JSI
  module Schema::Elements
    SELF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
          cxt_yield(schema)
        end

        element.add_action(:validate) do
          if schema_content == false
            validate(false, "instance is not valid against `false` schema")
          end
        end
      end
    end
  end
end
