# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS_PREFIXED = element_map do
      Schema::Element.new(keywords: %w(items prefixItems)) do |element|
      end
    end
  end
end
