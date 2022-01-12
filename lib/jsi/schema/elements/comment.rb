# frozen_string_literal: true

module JSI
  module Schema::Elements
    COMMENT = element_map do
      Schema::Element.new(keyword: '$comment') do |element|
      end # Schema::Element.new
    end # CONTENT_ENCODING = element_map
  end # module Schema::Elements
end
