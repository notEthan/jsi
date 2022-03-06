# frozen_string_literal: true

module JSI
  # JSI::Util contains public utilities
  module Util
    autoload :Private, 'jsi/util/private'

    include Private

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

    extend self
  end
  public
  extend Util
end
