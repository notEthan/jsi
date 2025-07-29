# frozen_string_literal: true

module JSI
  # a Set of JSI Schemas. always frozen.
  #
  # any schema instance is described by a set of schemas.
  class SchemaSet < Set
    COMPARE_BY_IDENTITY_DEFINED = method_defined?(:compare_by_identity)
    private_constant(:COMPARE_BY_IDENTITY_DEFINED)

    class << self
      # Builds a SchemaSet, yielding a yielder to be called with each schema of the SchemaSet.
      #
      # @yield [Enumerator::Yielder]
      # @return [SchemaSet]
      def build(&block)
        new(Enumerator.new(&block))
      end
    end

    # initializes a SchemaSet from the given enum and freezes it.
    #
    # if a block is given, each element of the enum is passed to it, and the result must be a Schema.
    # if no block is given, the enum must contain only Schemas.
    #
    # @param enum [#each] the schemas to be included in the SchemaSet, or items to be passed to the block
    # @yieldparam yields each element of `enum` for preprocessing into a Schema
    # @yieldreturn [JSI::Schema]
    # @raise [JSI::Schema::NotASchemaError]
    def initialize(enum, &block)
      if enum.is_a?(Schema)
        raise(ArgumentError, [
          "#{SchemaSet} initialized with a #{Schema}",
          "you probably meant to pass that to #{SchemaSet}[]",
          "or to wrap that schema in a Set or Array for #{SchemaSet}.new",
          "given: #{enum.pretty_inspect.chomp}",
        ].join("\n"))
      end

      unless enum.is_a?(Enumerable)
        raise(ArgumentError, "#{SchemaSet} initialized with non-Enumerable: #{enum.pretty_inspect.chomp}")
      end

      super(&nil) # note super() does implicitly pass block without &nil
      if COMPARE_BY_IDENTITY_DEFINED
        compare_by_identity
      else
        # TODO rm when Set#compare_by_identity is universally available.
        # note does not work on JRuby, but JRuby has Set#compare_by_identity.
        @hash.compare_by_identity
      end

      if block
        enum.each_entry { |o| add(block[o]) }
      else
        merge(enum)
      end

      not_schemas = reject { |s| s.is_a?(Schema) }
      if !not_schemas.empty?
        raise(Schema::NotASchemaError, [
          "#{SchemaSet} initialized with non-schema objects:",
          *not_schemas.map { |ns| ns.pretty_inspect.chomp },
        ].join("\n"))
      end

      freeze
    end

    # Instantiates a new JSI whose content comes from the given `instance` param.
    # This SchemaSet indicates the schemas of the JSI - its schemas are in-place
    # applicators of this set's schemas which apply to the given instance.
    #
    # @param instance [Object] the instance to be represented as a JSI
    # @param uri [#to_str, URI] The retrieval URI of the instance.
    #
    #   It is rare that this needs to be specified, and only useful for instances which contain schemas.
    #   See {Schema::MetaSchema#new_schema}'s `uri` param documentation.
    # @param register [Boolean] Whether schema resources in the instantiated JSI will be registered
    #   in the schema registry indicated by param `registry`.
    #   This is only useful when the JSI is a schema or contains schemas.
    #   The JSI's root will be registered with the `uri` param, if specified, whether or not the
    #   root is a schema.
    # @param registry [Registry, nil] The registry to use for references to other schemas and,
    #    depending on `register` and `uri` params, to register this JSI and/or any contained schemas with
    #    declared URIs.
    # @param stringify_symbol_keys [Boolean] Whether the instance content will have any Symbol keys of Hashes
    #   replaced with Strings (recursively through the document).
    #   Replacement is done on a copy; the given instance is not modified.
    # @param to_immutable [#call, nil] A proc/callable which takes given instance content
    #   and results in an immutable (i.e. deeply frozen) object equal to that.
    #   If the instantiated JSI will be mutable, this is not used.
    #   Though not recommended, this may be nil with immutable JSIs if the instance content is otherwise
    #   guaranteed to be immutable, as well as any modified copies of the instance.
    # @param mutable [Boolean] Whether the instantiated JSI will be mutable.
    #   The instance content will be transformed with `to_immutable` if the JSI will be immutable.
    # @return [Base] a JSI whose content comes from the given instance and whose schemas are
    #   in-place applicators of the schemas in this set.
    def new_jsi(instance,
        uri: nil,
        register: false,
        registry: JSI.registry,
        stringify_symbol_keys: false,
        to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
        mutable: false
    )
      instance = Util.deep_stringify_symbol_keys(instance) if stringify_symbol_keys

      instance = to_immutable.call(instance) if !mutable && to_immutable

      applied_schemas = SchemaSet.build do |y|
        c = y.method(:yield) # TODO drop c, just pass y, when all supported Enumerator::Yielder.method_defined?(:to_proc)
        each { |is| is.each_inplace_applicator_schema(instance, &c) }
      end

      uri = Util.uri(uri, nnil: false, yabs: true)

      jsi_class = JSI::SchemaClasses.class_for_schemas(applied_schemas,
        includes: SchemaClasses.includes_for(instance),
        mutable: mutable,
      )
      jsi = jsi_class.new(instance,
        jsi_indicated_schemas: self,
        jsi_schema_base_uri: uri,
        jsi_registry: registry,
        jsi_content_to_immutable: to_immutable,
      )

      registry.register(jsi) if register && registry

      jsi
    end

    # validates the given instance against our schemas
    #
    # @param instance [Object] the instance to validate against our schemas
    # @return [JSI::Validation::Result]
    def instance_validate(instance)
      inject(Validation::Result::Full.new) do |result, schema|
        result.merge(schema.instance_validate(instance))
      end.freeze
    end

    # whether the given instance is valid against our schemas
    # @param instance [Object] the instance to validate against our schemas
    # @return [Boolean]
    def instance_valid?(instance)
      all? { |schema| schema.instance_valid?(instance) }
    end

    # Builds a SchemaSet, yielding each schema and a callable to be called with each schema of the resulting SchemaSet.
    # @yield [Schema, #to_proc]
    # @return [SchemaSet]
    def each_yield_set(&block)
      self.class.new(Enumerator.new do |y|
        c = y.method(:yield) # TODO drop c, just pass y, when all supported Enumerator::Yielder.method_defined?(:to_proc)
        each { |schema| yield(schema, c) }
      end)
    end
  end
end
