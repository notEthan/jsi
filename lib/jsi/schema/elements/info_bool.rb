# frozen_string_literal: true

module JSI
  module Schema::Elements
    INFO_BOOL = element_map do |keyword: |
      Schema::Element.new(keyword: keyword) do |element|
      end # Schema::Element.new
    end # INFO_BOOL = element_map
  end # module Schema::Elements
end
