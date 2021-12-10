# frozen_string_literal: true

module JSI
  # JSI::Util::Private classes, modules, constants, and methods are internal, and will be added and removed without warning.
  #
  # @api private
  module Util::Private
    autoload :AttrStruct, 'jsi/util/private/attr_struct'

    EMPTY_ARY = [].freeze

    EMPTY_SET = Set[].freeze

    # is the given name ok to use as a ruby method name?
    def ok_ruby_method_name?(name)
      # must be a string
      return false unless name.respond_to?(:to_str)
      # must not begin with a digit
      return false if name =~ /\A[0-9]/
      # must not contain characters special to ruby syntax
      return false if name =~ /[\\\s\#;\.,\(\)\[\]\{\}'"`%\+\-\/\*\^\|&=<>\?:!@\$~]/

      return true
    end

    # this is the Y-combinator, which allows anonymous recursive functions. for a simple example,
    # to define a recursive function to return the length of an array:
    #
    #     length = ycomb do |len|
    #       proc { |list| list == [] ? 0 : 1 + len.call(list[1..-1]) }
    #     end
    #
    #     length.call([0])
    #     # => 1
    #
    # see https://en.wikipedia.org/wiki/Fixed-point_combinator#Y_combinator
    # and chapter 9 of the little schemer, available as the sample chapter at
    # https://felleisen.org/matthias/BTLS-index.html
    def ycomb
      proc { |f| f.call(f) }.call(proc { |f| yield proc { |*x| f.call(f).call(*x) } })
    end

    module FingerprintHash
      # overrides BasicObject#==
      def ==(other)
        __id__ == other.__id__ || (other.respond_to?(:jsi_fingerprint) && other.jsi_fingerprint == jsi_fingerprint)
      end

      alias_method :eql?, :==

      # overrides Kernel#hash
      def hash
        jsi_fingerprint.hash
      end
    end

    class MemoMap
      Result = AttrStruct[*%w(
        value
        inputs
        inputs_hash
      )]

      class Result
      end

      def initialize(key_by: nil, &block)
        @key_by = key_by
        @block = block

        # each result has its own mutex to update its memoized value thread-safely
        @result_mutexes = {}
        # another mutex to thread-safely initialize each result mutex
        @result_mutexes_mutex = Mutex.new

        @results = {}
      end

      def [](*inputs)
        if @key_by
          key = @key_by.call(*inputs)
        else
          key = inputs
        end
        result_mutex = @result_mutexes_mutex.synchronize do
          @result_mutexes[key] ||= Mutex.new
        end

        result_mutex.synchronize do
          inputs_hash = inputs.hash
          if @results.key?(key) && inputs_hash == @results[key].inputs_hash && inputs == @results[key].inputs
            @results[key].value
          else
            value = @block.call(*inputs)
            @results[key] = Result.new(value: value, inputs: inputs, inputs_hash: inputs_hash)
            value
          end
        end
      end
    end

    module Memoize
      def self.extended(object)
        object.send(:jsi_initialize_memos)
      end

      private

      def jsi_initialize_memos
        @jsi_memomaps_mutex = Mutex.new
        @jsi_memomaps = {}
      end

      # @return [Util::MemoMap]
      def jsi_memomap(name, **options, &block)
        raise(Bug, 'must jsi_initialize_memos') unless @jsi_memomaps
        unless @jsi_memomaps.key?(name)
          @jsi_memomaps_mutex.synchronize do
            # note: this ||= appears redundant with `unless @jsi_memomaps.key?(name)`,
            # but that check is not thread safe. this check is.
            @jsi_memomaps[name] ||= Util::MemoMap.new(**options, &block)
          end
        end
        @jsi_memomaps[name]
      end

      def jsi_memoize(name, *inputs, &block)
        jsi_memomap(name, &block)[*inputs]
      end
    end

    module Virtual
      class InstantiationError < StandardError
      end

      # this virtual class is not intended to be instantiated except by its subclasses, which override #initialize
      def initialize
        # :nocov:
        raise(InstantiationError, "cannot instantiate virtual class #{self.class}")
        # :nocov:
      end

      # virtual_method is used to indicate that the method calling it must be implemented on the (non-virtual) subclass
      def virtual_method
        # :nocov:
        raise(Bug, "class #{self.class} must implement #{caller_locations.first.label}")
        # :nocov:
      end
    end

    public

    extend self
  end
end
