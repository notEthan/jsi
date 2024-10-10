# frozen_string_literal: true

module JSI
  # JSI::URI adds to Addressable::URI:
  #
  # - always immutable
  # - `JSI::URI["http://x"]` parses, and JSI::URI#inspect shows this form, copy/pastable
  class URI < Addressable::URI
    class << self
      # @param uri [#to_str]
      # @return [URI]
      def [](uri)
        parse(uri)
      end
    end

    def initialize(options={})
      super
      freeze
    end

    def merge(hash)
      # Addressable::URI#merge instantiates and mutates, not compatible with #initialize freezing. work around.
      self.class.new(Addressable::URI.new(to_hash).merge(hash).to_hash)
    end

    # @return [String]
    def inspect
      -"#{self.class}[#{to_s.inspect}]"
    end
  end
end
