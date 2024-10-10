# frozen_string_literal: true

module JSI
  # JSI::URI adds to Addressable::URI:
  #
  # - `JSI::URI["http://x"]` parses, and JSI::URI#inspect shows this form, copy/pastable
  class URI < Addressable::URI
    class << self
      # @param uri [#to_str]
      # @return [URI]
      def [](uri)
        parse(uri)
      end
    end

    # @return [String]
    def inspect
      -"#{self.class}[#{to_s.inspect}]"
    end
  end
end
