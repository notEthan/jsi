# frozen_string_literal: true

module JSI
  # a Set of JSI Schemas. always frozen.
  #
  # any schema instance is described by a set of schemas.
  class SchemaSet < Set
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

      compare_by_identity

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
    # @param stringify_symbol_keys [Boolean] Whether the instance content will have any Symbol keys of Hashes
    #   replaced with Strings (recursively through the document).
    #   Replacement is done on a copy; the given instance is not modified.
    # @param conf_kw Additional keyword params are passed to initialize a {Base::Conf}, the JSI's {Base#jsi_conf}.
    # @return [Base] a JSI whose content comes from the given instance and whose schemas are
    #   in-place applicators of the schemas in this set.
    def new_jsi(instance,
        stringify_symbol_keys: false,
        **conf_kw
    )
      raise(BlockGivenError) if block_given?

      conf = Base::Conf.new(root_indicated_schemas: self, **conf_kw)

      instance = Util.jsi_in_content(instance, action: conf.jsi_in_content)

      instance = Util.deep_stringify_symbol_keys(instance) if stringify_symbol_keys

      jsi = conf[instance]

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
