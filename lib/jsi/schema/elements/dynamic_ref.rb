# frozen_string_literal: true

module JSI
  module Schema::Elements
    DYNAMIC_REF = element_map do
      Schema::Element.new(keyword: '$dynamicRef') do |element|
        resolve_dynamicRef = proc do
        end
      end
    end
  end
end
