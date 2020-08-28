# frozen_string_literal: true

module JSI
  module Schema::Elements
    UNEVALUATED_PROPERTIES = element_map do
      Schema::Element.new(keyword: 'unevaluatedProperties') do |element|
      end
    end
  end
end
