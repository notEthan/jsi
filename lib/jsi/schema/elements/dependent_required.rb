# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENT_REQUIRED = element_map do
      Schema::Element.new(keyword: 'dependentRequired') do |element|
      end
    end
  end
end
