# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENT_SCHEMAS = element_map do
      Schema::Element.new(keyword: 'dependentSchemas') do |element|
      end
    end
  end
end
