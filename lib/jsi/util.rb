# frozen_string_literal: true

module JSI
  module Util
    # a proc which does nothing
    NOOP = -> (*_) { }

    # returns a version of the given hash, in which any symbol keys are
    # converted to strings. behavior on collisions is undefined (but in the
    # future could take a block like
    # ActiveSupport::HashWithIndifferentAccess#update)
    #
    # at the moment it is undefined whether the returned hash is the same
    # instance as the `hash` param. if `hash` is already a hash  which contains
    # no symbol keys, this method MAY return that same instance. use #dup on
    # the return if you need to ensure it is not the same instance as the
    # argument instance.
    #
    # @param hash [#to_hash] the hash from which to convert symbol keys to strings
    # @return [same class as the param `hash`, or Hash if the former cannot be done] a
    #    hash(-like) instance containing no symbol keys
    def stringify_symbol_keys(hashlike)
      unless hashlike.respond_to?(:to_hash)
        raise(ArgumentError, "expected argument to be a hash; got #{hashlike.class.inspect}: #{hashlike.pretty_inspect.chomp}")
      end
      JSI::Typelike.modified_copy(hashlike) do |hash|
        out = {}
        hash.each do |k, v|
          out[k.is_a?(Symbol) ? k.to_s : k] = v
        end
        out
      end
    end

    def deep_stringify_symbol_keys(object)
      if object.respond_to?(:to_hash)
        JSI::Typelike.modified_copy(object) do |hash|
          out = {}
          (hash.respond_to?(:each) ? hash : hash.to_hash).each do |k, v|
            out[k.is_a?(Symbol) ? k.to_s : deep_stringify_symbol_keys(k)] = deep_stringify_symbol_keys(v)
          end
          out
        end
      elsif object.respond_to?(:to_ary)
        JSI::Typelike.modified_copy(object) do |ary|
          (ary.respond_to?(:each) ? ary : ary.to_ary).map do |e|
            deep_stringify_symbol_keys(e)
          end
        end
      else
        object
      end
    end

    # this is the Y-combinator, which allows anonymous recursive functions. for a simple example,
    # to define a recursive function to return the length of an array:
    #
    #    length = ycomb do |len|
    #      proc{|list| list == [] ? 0 : 1 + len.call(list[1..-1]) }
    #    end
    #
    # see https://secure.wikimedia.org/wikipedia/en/wiki/Fixed_point_combinator#Y_combinator
    # and chapter 9 of the little schemer, available as the sample chapter at http://www.ccs.neu.edu/home/matthias/BTLS/
    def ycomb
      proc { |f| f.call(f) }.call(proc { |f| yield proc { |*x| f.call(f).call(*x) } })
    end
    module_function :ycomb
  end
  public
  extend Util

  module FingerprintHash
    def ==(other)
      object_id == other.object_id || (other.respond_to?(:jsi_fingerprint) && other.jsi_fingerprint == self.jsi_fingerprint)
    end

    alias_method :eql?, :==

    def hash
      jsi_fingerprint.hash
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

    def clear_memo(key, *args)
      @memos ||= {}
      if @memos[key]
        if args.empty?
          @memos[key].clear
        else
          @memos[key].delete(args)
        end
      end
    end
  end
  extend Memoize
end
