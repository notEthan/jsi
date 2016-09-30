require "scorpio/version"

module Scorpio
  autoload :Model, 'scorpio/model'

  class << self
    def stringify_symbol_keys(hash)
      unless hash.is_a?(Hash)
        raise ArgumentError, "expected argument to be a Hash; got #{hash.class}: #{hash.inspect}"
      end
      hash.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
    end
  end
end
