module Scorpio
  module Util
    def stringify_symbol_keys(hash)
      unless hash.respond_to?(:to_hash)
        raise(ArgumentError, "expected argument to be a hash; got #{hash.class}: #{hash.pretty_inspect.chomp}")
      end
      Scorpio::Typelike.modified_copy(hash) do |hash_|
        hash_.map { |k, v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
      end
    end
  end
  extend Util

  module FingerprintHash
    def ==(other)
      object_id == other.object_id || (other.respond_to?(:fingerprint) && other.fingerprint == self.fingerprint)
    end

    alias_method :eql?, :==

    def hash
      fingerprint.hash
    end
  end

  module Memoize
    def memoize(key, *args_)
      @memos ||= {}
      @memos[key] ||= Hash.new do |h, args|
        h[args] = yield(*args)
      end
      @memos[key][args_]
    end
  end
  extend Memoize
end
