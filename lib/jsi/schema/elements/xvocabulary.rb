# frozen_string_literal: true

module JSI
  module Schema::Elements
    XVOCABULARY = element_map do
      Schema::Element.new(keyword: '$vocabulary') do |element|
      end
    end
  end
end
