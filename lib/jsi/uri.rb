# frozen_string_literal: true

module JSI
  # JSI::URI adds to Addressable::URI:
  #
  # - `JSI::URI["http://x"]` parses, and JSI::URI#inspect shows this form, copy/pastable
  # - Immutable when instantiated with `.[]`, `.parse`, or modified-copy instance methods join, merge, or normalize.
  #   However `.new` and `#dup` do not freeze for compatibility with some libraries (Faraday) that dup and mutate URIs.
  # @private
  class URI < Addressable::URI
    class << self
      # @param uri [#to_str]
      # @return [URI]
      def [](uri)
        parse(uri)
      end

      def parse(uri)
        super.freeze
      end
    end

    def join(uri)
      super.freeze
    end

    def merge(hash)
      super.freeze
    end

    def normalize
      super.freeze
    end

    # @return [String]
    def inspect
      -"#{self.class}[#{to_s.inspect}]"
    end
  end
end
