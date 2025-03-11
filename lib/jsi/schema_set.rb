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
    #
    # The schemas of the JSI (its {Base#jsi_schemas}) are in-place
    # applicators of this set's schemas which apply to the given instance.
    # The JSI's {Base#jsi_indicated_schemas} set is this set.
    #
    # The resulting JSI is an instance of a number of modules:
    #
    # - The {SchemaModule JSI schema module} of each applicator schema.
    # - {Base::HashNode}, {Base::ArrayNode}, or {Base::StringNode} if the instance is
    #   a hash/object, array, or string.
    # - A module defining readers for properties described by applicator schemas.
    #   If the instance is mutable, writers as well.
    #
    # @param instance [Object] the instance to be represented as a JSI
    # @param base_uri [#to_str, URI, nil]
    #   The base URI of the instance document. An absolute URI.
    #
    #   It is rare that this needs to be specified. It is useful when the instance contains schemas,
    #   and schemas in the document use relative URIs for `$id` or `$ref` without an absolute id
    #   in an ancestor schema - those URIs will be resolved relative to `base_uri`.
    #
    #   See also {Base::Conf conf} {Base::Conf#root_uri `root_uri`}. `base_uri` is not used to identify
    #   any resource, only to resolve relative URIs. `root_uri` does identify the root resource.
    # @param register [Boolean] Whether schema resources in the instantiated JSI will be registered
    #   in the {Base::Conf configured} {Base::Conf#registry `registry`}.
    #   This is only useful when the JSI is a schema or contains schemas.
    # @param stringify_symbol_keys [Boolean] Whether the instance content will have any Symbol keys of Hashes
    #   replaced with Strings (recursively through the document).
    #   Replacement is done on a copy; the given instance is not modified.
    # @param mutable [Boolean] Whether the instantiated JSI will be mutable.
    #   The instance content will be transformed with the {Base::Conf configured}
    #   {Base::Conf#to_immutable `to_immutable`} if the JSI will be immutable.
    # @param conf_kw Additional keyword params are passed to initialize a {Base::Conf}, the JSI's {Base#jsi_conf}.
    # @return [Base] a JSI whose content comes from the given instance and whose schemas are
    #   in-place applicators of the schemas in this set.
    def new_jsi(instance,
        base_uri: nil,
        register: false,
        stringify_symbol_keys: false,
        mutable: false,
        **conf_kw
    )
      raise(BlockGivenError) if block_given?

      conf = Base::Conf.new(**conf_kw)

      instance = Util.deep_stringify_symbol_keys(instance) if stringify_symbol_keys

      instance = conf.to_immutable.call(instance) if !mutable && conf.to_immutable

      applied_schemas = SchemaSet.build do |y|
        c = y.method(:yield) # TODO drop c, just pass y, when all supported Enumerator::Yielder.method_defined?(:to_proc)
        each { |is| is.each_inplace_applicator_schema(instance, &c) }
      end

      base_uri = Util.uri(base_uri, nnil: false, yabs: true) || conf.root_uri

      jsi_class = JSI::SchemaClasses.class_for_schemas(applied_schemas,
        includes: SchemaClasses.includes_for(instance),
        mutable: mutable,
      )
      jsi = jsi_class.new(
        jsi_document: instance,
        jsi_indicated_schemas: self,
        jsi_base_uri: base_uri,
        jsi_conf: conf,
      ).send(:jsi_initialized)

      conf.registry.register(jsi) if register && conf.registry

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

    # @return [Set<SchemaModule>]
    def jsi_schema_modules
      Set.new(self, &:jsi_schema_module).freeze
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
