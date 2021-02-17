# frozen_string_literal: true

module JSI
  # JSI::Util contains public utilities
  module Util
    autoload :Private, 'jsi/util/private'

    include Private

    extend self

    autoload :Arraylike, 'jsi/util/typelike'
    autoload :Hashlike, 'jsi/util/typelike'

    # yields the content of the given param `object`. for objects which have a #jsi_modified_copy
    # method of their own (JSI::Base, JSI::MetaschemaNode) that method is invoked with the given
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

    # recursive method to express the given argument object in json-compatible
    # types of Hash, Array, and basic types of String/boolean/numeric/nil. this
    # will raise TypeError if an object is given that is not a type that seems
    # to be expressable as json.
    #
    # similar effect could be achieved by requiring 'json/add/core' and using #as_json,
    # but I don't much care for how it represents classes that are
    # not naturally expressable in JSON, and prefer not to load its
    # monkey-patching.
    #
    # @param object [Object] the object to be converted to jsonifiability
    # @return [Array, Hash, String, Boolean, NilClass, Numeric] jsonifiable
    #   expression of param object
    # @raise [TypeError] when the object (or an object nested with a hash or
    #   array of object) cannot be expressed as json
    def as_json(object, *opt)
      if object.is_a?(JSI::Base)
        as_json(object.jsi_node_content, *opt)
      elsif object.respond_to?(:to_hash)
        (object.respond_to?(:map) ? object : object.to_hash).map do |k, v|
          unless k.is_a?(Symbol) || k.respond_to?(:to_str)
            raise(TypeError, "json object (hash) cannot be keyed with: #{k.pretty_inspect.chomp}")
          end
          {k.to_s => as_json(v, *opt)}
        end.inject({}, &:update)
      elsif object.respond_to?(:to_ary)
        (object.respond_to?(:map) ? object : object.to_ary).map { |e| as_json(e, *opt) }
      elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| object.is_a?(c) }
        object
      elsif object.is_a?(Symbol)
        object.to_s
      elsif object.is_a?(Set)
        as_json(object.to_a, *opt)
      elsif object.respond_to?(:as_json)
        as_json(object.as_json(*opt), *opt)
      else
        raise(TypeError, "cannot express object as json: #{object.pretty_inspect.chomp}")
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
      if object.respond_to?(:to_hash) && !object.is_a?(Addressable::URI)
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
    def deep_to_frozen(object)
      if object.instance_of?(Hash)
        out = {}
        object.each do |k, v|
          out[deep_to_frozen(k)] = deep_to_frozen(v)
        end
        out.freeze
      elsif object.instance_of?(Array)
        object.map do |e|
          deep_to_frozen(e)
        end.freeze
      elsif object.instance_of?(String)
        object.dup.freeze
      elsif CLASSES_ALWAYS_FROZEN.any? { |c| object.instance_of?(c) }
        object
      else
          raise(NotImplementedError, [
            "deep_to_frozen not implemented for class: #{object.class}",
            "object: #{object.pretty_inspect.chomp}",
          ].join("\n"))
      end
    end

    # ensures the given param becomes a frozen Set of Modules.
    # returns the param if it is already that, otherwise initializes and freezes such a Set.
    #
    # @param modules [Set, Enumerable] the object to ensure becomes a frozen Set of Modules
    # @return [Set] frozen Set containing the given modules
    # @raise [ArgumentError] when the modules param is not an Enumerable
    # @raise [Schema::NotASchemaError] when the modules param contains objects which are not Schemas
    def ensure_module_set(modules)
      if modules.is_a?(Set) && modules.frozen?
        set = modules
      else
        set = Set.new(modules).freeze
      end
      not_modules = set.reject { |s| s.is_a?(Module) }
      if !not_modules.empty?
        raise(TypeError, [
          "ensure_module_set given non-Module objects:",
          *not_modules.map { |ns| ns.pretty_inspect.chomp },
        ].join("\n"))
      end

      set
    end
  end
end
