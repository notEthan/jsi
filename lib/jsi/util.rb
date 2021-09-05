# frozen_string_literal: true

module JSI
  # JSI::Util classes, modules, constants, and methods are internal, and will be added and removed without warning.
  module Util
    autoload :AttrStruct, 'jsi/util/attr_struct'

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
    # @param hashlike [#to_hash] the hash from which to convert symbol keys to strings
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

    # ensures the given param becomes a frozen Set of Modules.
    # returns the param if it is already that, otherwise initializes and freezes such a Set.
    #
    # @param modules [Set, Enumerable] the object to ensure becomes a frozen Set of Modules
    # @return [SchemaSet] the given SchemaSet, or a SchemaSet initialized from the given Enumerable
    # @raise [ArgumentError] when the modules param is not an Enumerable
    # @raise [Schema::NotASchemaError] when the modules param contains objects which are not Schemas
    def ensure_module_set(modules)
      if modules.is_a?(Set) && modules.frozen?
        modules
      else
        set = Set.new(modules).freeze

        not_modules = set.reject { |s| s.is_a?(Module) }
        if !not_modules.empty?
          raise(TypeError, [
            "ensure_module_set give non-Module objects:",
            *not_modules.map { |ns| ns.pretty_inspect.chomp },
          ].join("\n"))
        end

        set
      end
    end

    # this is the Y-combinator, which allows anonymous recursive functions. for a simple example,
    # to define a recursive function to return the length of an array:
    #
    #    length = ycomb do |len|
    #      proc { |list| list == [] ? 0 : 1 + len.call(list[1..-1]) }
    #    end
    #
    # see https://secure.wikimedia.org/wikipedia/en/wiki/Fixed_point_combinator#Y_combinator
    # and chapter 9 of the little schemer, available as the sample chapter at http://www.ccs.neu.edu/home/matthias/BTLS/
    def ycomb
      proc { |f| f.call(f) }.call(proc { |f| yield proc { |*x| f.call(f).call(*x) } })
    end

    module FingerprintHash
      # overrides BasicObject#==
      def ==(other)
        __id__ == other.__id__ || (other.respond_to?(:jsi_fingerprint) && other.jsi_fingerprint == self.jsi_fingerprint)
      end

      alias_method :eql?, :==

      # overrides Kernel#hash
      def hash
        jsi_fingerprint.hash
      end
    end

    class MemoMap
      Result = Util::AttrStruct[*%w(
        value
        inputs
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
          if @results.key?(key) && inputs == @results[key].inputs
            @results[key].value
          else
            value = @block.call(*inputs)
            @results[key] = Result.new(value: value, inputs: inputs)
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
  public
  extend Util
end
