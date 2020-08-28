# frozen_string_literal: true

module JSI
  module Schema::Elements
    UNEVALUATED_ITEMS = element_map do
      Schema::Element.new(keyword: 'unevaluatedItems') do |element|
      end
    end
  end
end
