# frozen_string_literal: true

module JSI
  # JSI::Util::Private classes, modules, constants, and methods are internal, and will be added and removed without warning.
  #
  # @api private
  module Util::Private
    autoload :AttrStruct, 'jsi/util/private/attr_struct'
    autoload :MemoMap, 'jsi/util/private/memo_map'

    extend self

    EMPTY_ARY = [].freeze

    EMPTY_SET = Set[].freeze

    # is a hash as the last argument passed to keyword params? (false in ruby 3; true before - generates
    # a warning in 2.7 but no way to make 2.7 behave like 3 so the warning is useless)
    #
    # TODO remove eventually (keyword argument compatibility)
    LAST_ARGUMENT_AS_KEYWORD_PARAMETERS = begin
      if Object.const_defined?(:Warning)
        warn = ::Warning.instance_method(:warn)
        ::Warning.send(:remove_method, :warn)
        ::Warning.send(:define_method, :warn) { |*, **| }
      end

      -> (k: ) { k }[{k: nil}]
      true
    rescue ArgumentError
      false
    ensure
      if Object.const_defined?(:Warning)
        ::Warning.send(:remove_method, :warn)
        ::Warning.send(:define_method, :warn, warn)
      end
    end

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

    # string or URI → frozen URI
    # @return [Addressable::URI]
    def uri(uri)
      if uri.is_a?(Addressable::URI)
        if uri.frozen?
          uri
        else
          uri.dup.freeze
        end
      else
        Addressable::URI.parse(uri).freeze
      end
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

    def require_jmespath
      return if instance_variable_defined?(:@jmespath_required)
      begin
        require 'jmespath'
      rescue ::LoadError => e
        # :nocov:
        msg = [
          "please install and/or add to your Gemfile the `jmespath` gem to use this. jmespath is not a dependency of JSI.",
          "original error message:",
          e.message,
        ].join("\n")
        raise(e.class, msg, e.backtrace)
        # :nocov:
      end
      hashlike = JSI::SchemaSet[].new_jsi({'test' => 0})
      unless JMESPath.search('test', hashlike) == 0
        # :nocov:
        raise(::LoadError, [
          "the loaded version of jmespath cannot be used with JSI.",
          "jmespath is compatible with JSI objects as of version 1.5.0",
        ].join("\n"))
        # :nocov:
      end
      @jmespath_required = true
      nil
    end

    # Defines equality methods and #hash (for Hash / Set), based on a method #jsi_fingerprint
    # implemented by the includer. #jsi_fingerprint is to include the class and any properties
    # of the instance which constitute its identity.
    module FingerprintHash
      # overrides BasicObject#==
      def ==(other)
        __id__ == other.__id__ || (other.is_a?(FingerprintHash) && jsi_fingerprint == other.jsi_fingerprint)
      end

      alias_method :eql?, :==

      # overrides Kernel#hash
      def hash
        jsi_fingerprint.hash
      end
    end

    module FingerprintHash::Immutable
      include FingerprintHash

      def ==(other)
        return true if __id__ == other.__id__
        return false unless other.is_a?(FingerprintHash)
        # FingerprintHash::Immutable#hash being memoized, comparing that is basically free.
        # not done with FingerprintHash, its #hash can be expensive.
        return false if other.is_a?(FingerprintHash::Immutable) && hash != other.hash
        jsi_fingerprint == other.jsi_fingerprint
      end

      alias_method :eql?, :==

      def hash
        @jsi_fingerprint_hash ||= jsi_fingerprint.hash
      end

      def freeze
        hash
        super
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
      def jsi_memomap(name = nil, **options, &block)
        return Util::MemoMap.new(**options, &block) if !name
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

      def jsi_memoize(name, **inputs, &block)
        jsi_memomap(name, &block)[**inputs]
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
  end
end
