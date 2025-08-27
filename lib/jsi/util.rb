# frozen_string_literal: true

require("delegate")

module JSI
  # JSI::Util contains public utilities
  module Util
    autoload :Private, 'jsi/util/private'

    # common methods of inspecting / pretty-printing
    # @private (not in Util::Private due to dependency order)
    module Pretty
      # @return [String]
      def inspect
        out = String.new
        PP.singleline_pp(self, out)
        out.freeze
      end

      # @return [String]
      def to_s
        inspect
      end

      private

      def jsi_pp_object_group(q, pres = [self.class.name].freeze, empty: false)
        q.text('#<')
        pres.each_with_index do |pre, i|
          q.text(' ') if i != 0
          q.text(pre.to_s)
        end
        if block_given? && !empty
          q.group do
            q.nest(2) do
              q.breakable(' ')
              yield
            end
            q.breakable('')
          end
        end
        q.text('>')
      end
    end

    include Private

    extend self

    autoload :Arraylike, 'jsi/util/typelike'
    autoload :Hashlike, 'jsi/util/typelike'

    # yields the content of the given param `object`. for objects which have a #jsi_modified_copy
    # method of their own (JSI::Base, JSI::MetaSchemaNode) that method is invoked with the given
    # block. otherwise the given object itself is yielded.
    #
    # the given block must result in a modified copy of its block parameter
    # (not destructively modifying the yielded content).
    #
    # @yield [Object] the content of the given object. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [object.class] modified copy of the given object
    def modified_copy(object, &block)
      if object.respond_to?(:jsi_modified_copy)
        object.jsi_modified_copy(&block)
      else
        yield(object)
      end
    end

    # A structure like the given `object`, recursively coerced to JSON-compatible types.
    #
    # - Structures of Hash, Array, and simple types of String/number/boolean/nil are returned as-is.
    # - If the object responds to `#as_json`, that method is used, passing any given options.
    # - If the object supports [implicit conversion](https://docs.ruby-lang.org/en/master/implicit_conversion_rdoc.html)
    #   with `#to_hash`, `#to_ary`, `#to_str`, or `#to_int`, that is used.
    # - Set becomes Array; Symbol becomes String.
    # - Types with no known coersion to JSON-compatible raise TypeError.
    #
    # @param object [Object]
    # @return [Array, Hash, String, Integer, Float, Boolean, NilClass] a JSON-compatible structure like the given `object`
    # @raise [TypeError] If the object cannot be coerced to a JSON-compatible structure
    def as_json(object, options = {})
      type_err = proc { raise(TypeError, "cannot express object as json: #{object.pretty_inspect.chomp}") }
      if object.respond_to?(:as_json)
        options.empty? ? object.as_json : object.as_json(**options) # TODO remove eventually (keyword argument compatibility)
      elsif object.is_a?(URI)
        object.to_s
      elsif object.respond_to?(:to_hash) && (object_to_hash = object.to_hash).is_a?(Hash)
        result = {}
        object_to_hash.each_pair do |k, v|
          ks = k.is_a?(String) ? k :
            k.is_a?(Symbol) ? k.to_s :
            k.respond_to?(:to_str) && (kstr = k.to_str).is_a?(String) ? kstr :
            raise(TypeError, "json object (hash) cannot be keyed with: #{k.pretty_inspect.chomp}")
          result[ks] = as_json(v, **options)
        end
        result
      elsif object.respond_to?(:to_ary) && (object_to_ary = object.to_ary).is_a?(Array)
        object_to_ary.map { |e| as_json(e, **options) }
      elsif [String, Integer, TrueClass, FalseClass, NilClass].any? { |c| object.is_a?(c) }
        object
      elsif object.is_a?(Float)
        type_err.call unless object.finite?
        object
      elsif object.is_a?(Symbol)
        object.to_s
      elsif object.is_a?(::Set)
        as_json(object.to_a, **options)
      elsif object.respond_to?(:to_str) && (object_to_str = object.to_str).is_a?(String)
        object_to_str
      elsif object.respond_to?(:to_int) && (object_to_int = object.to_int).is_a?(Integer)
        object_to_int
      else
        type_err.call
      end
    end

    # A JSON encoded string of the given object.
    #
    # - If the object has a `#to_json` method that isn't defined by the stdlib `json` gem,
    #   that method is used, passing any given options.
    # - Otherwise, JSON is generated using {as_json} to coerce to compatible types.
    # @return [String]
    def to_json(object, options = {})
      options_state = options.class.name =~ /\AJSON:.*:Generator::State\z/
      if USE_TO_JSON_METHOD[object.class]
        (options_state || !options.empty?) ? object.to_json(options) : object.to_json # TODO remove eventually (keyword argument compatibility)
      else
        if options_state
          JSON.generate(as_json(object), options)
        else
          JSON.generate(as_json(object, **options))
        end
      end
    end

    # a hash copied from the given hashlike, in which any symbol keys are
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
      JSI::Util.modified_copy(hashlike) do |hash|
        out = {}
        hash.each do |k, v|
          out[k.is_a?(Symbol) ? k.to_s : k] = v
        end
        out
      end
    end

    def deep_stringify_symbol_keys(object)
      if object.respond_to?(:to_hash) && !object.is_a?(URI)
        JSI::Util.modified_copy(object) do |hash|
          out = {}
          (hash.respond_to?(:each) ? hash : hash.to_hash).each do |k, v|
            out[k.is_a?(Symbol) ? k.to_s.freeze : deep_stringify_symbol_keys(k)] = deep_stringify_symbol_keys(v)
          end
          out
        end
      elsif object.respond_to?(:to_ary)
        JSI::Util.modified_copy(object) do |ary|
          (ary.respond_to?(:each) ? ary : ary.to_ary).map do |e|
            deep_stringify_symbol_keys(e)
          end
        end
      else
        object
      end
    end

    # returns an object which is equal to the param object, and is recursively frozen.
    # the given object is not modified.
    def deep_to_frozen(object, not_implemented: nil)
      dtf = proc { |o| deep_to_frozen(o, not_implemented: not_implemented) }
      if object.is_a?(Delegator)
        object.class.new(dtf[object.__getobj__]).freeze
      elsif object.instance_of?(Hash)
        out = {}
        identical = object.frozen?
        object.each do |k, v|
          fk = dtf[k]
          fv = dtf[v]
          identical &&= fk.__id__ == k.__id__
          identical &&= fv.__id__ == v.__id__
          out[fk] = fv
        end
        if !object.default.nil?
          out.default = dtf[object.default]
          identical &&= out.default.__id__ == object.default.__id__
        end
        if object.default_proc
          raise(ArgumentError, "cannot make immutable copy of a Hash with default_proc")
        end
        if identical
          object
        else
          out.freeze
        end
      elsif object.instance_of?(Array)
        identical = object.frozen?
        out = Array.new(object.size)
        object.each_with_index do |e, i|
          fe = dtf[e]
          identical &&= fe.__id__ == e.__id__
          out[i] = fe
        end
        if identical
          object
        else
          out.freeze
        end
      elsif object.instance_of?(String)
        if object.frozen?
          object
        else
          object.dup.freeze
        end
      elsif CLASSES_ALWAYS_FROZEN.any? { |c| object.is_a?(c) } # note: `is_a?`, not `instance_of?`, here because instance_of?(Integer) is false until Fixnum/Bignum is gone. this is fine here; there is no concern of subclasses of CLASSES_ALWAYS_FROZEN duping/freezing differently (as with e.g. ActiveSupport::HashWithIndifferentAccess)
        object
      else
        if not_implemented
          not_implemented.call(object)
        else
          raise(NotImplementedError, [
            "deep_to_frozen not implemented for class: #{object.class}",
            "object: #{object.pretty_inspect.chomp}",
          ].join("\n"))
        end
      end
    end
  end
end
