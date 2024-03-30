# frozen_string_literal: true

module JSI
  # a Set of JSI Schemas. always frozen.
  #
  # any schema instance is described by a set of schemas.
  class SchemaSet < ::Set
    class << self
      # Builds a SchemaSet, yielding a yielder to be called with each schema of the SchemaSet.
      #
      # @yield [Enumerator::Yielder]
      # @return [SchemaSet]
      def build(&block)
        new(Enumerator.new(&block))
      end

      # ensures the given param becomes a SchemaSet. returns the param if it is already SchemaSet, otherwise
      # initializes a SchemaSet from it.
      #
      # @param schemas [SchemaSet, Enumerable] the object to ensure becomes a SchemaSet
      # @return [SchemaSet] the given SchemaSet, or a SchemaSet initialized from the given Enumerable
      # @raise [ArgumentError] when the schemas param is not an Enumerable
      # @raise [Schema::NotASchemaError] when the schemas param contains objects which are not Schemas
      def ensure_schema_set(schemas)
        if schemas.is_a?(SchemaSet)
          schemas
        else
          new(schemas)
        end
      end
    end

    # initializes a SchemaSet from the given enum and freezes it.
    #
    # if a block is given, each element of the enum is passed to it, and the result must be a Schema.
    # if no block is given, the enum must contain only Schemas.
    #
    # @param enum [#each] the schemas to be included in the SchemaSet, or items to be passed to the block
    # @yieldparam yields each element of enum for preprocessing into a Schema
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

      super

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
    # This SchemaSet indicates the schemas of the JSI - its schemas are inplace
    # applicators of this set's schemas which apply to the given instance.
    #
    # @param instance [Object] the instance to be represented as a JSI
    # @param uri [#to_str, Addressable::URI] The retrieval URI of the instance.
    #
    #   It is rare that this needs to be specified, and only useful for instances which contain schemas.
    #   See {Schema::DescribesSchema#new_schema}'s `uri` param documentation.
    # @param register [Boolean] Whether schema resources in the instantiated JSI will be registered
    #   in the schema registry indicated by param `schema_registry`.
    #   This is only useful when the JSI is a schema or contains schemas.
    #   The JSI's root will be registered with the `uri` param, if specified, whether or not the
    #   root is a schema.
    # @param schema_registry [SchemaRegistry, nil] The registry to use for references to other schemas and,
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
    # @return [JSI::Base subclass] a JSI whose content comes from the given instance and whose schemas are
    #   inplace applicators of the schemas in this set.
    def new_jsi(instance,
        uri: nil,
        register: false,
        schema_registry: JSI.schema_registry,
        stringify_symbol_keys: false,
        to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
        mutable: true
    )
      instance = Util.deep_stringify_symbol_keys(instance) if stringify_symbol_keys

      instance = to_immutable.call(instance) if !mutable && to_immutable

      applied_schemas = inplace_applicator_schemas(instance)

      if uri
        unless uri.respond_to?(:to_str)
          raise(TypeError, "uri must be string or Addressable::URI; got: #{uri.inspect}")
        end
        uri = Util.uri(uri)
        unless uri.absolute? && !uri.fragment
          raise(ArgumentError, "uri must be an absolute URI with no fragment; got: #{uri.inspect}")
        end
      end

      jsi_class = JSI::SchemaClasses.class_for_schemas(applied_schemas,
        includes: SchemaClasses.includes_for(instance),
        mutable: mutable,
      )
      jsi = jsi_class.new(instance,
        jsi_indicated_schemas: self,
        jsi_schema_base_uri: uri,
        jsi_schema_registry: schema_registry,
        jsi_content_to_immutable: to_immutable,
      )

      schema_registry.register(jsi) if register && schema_registry

      jsi
    end

    # a set of inplace applicator schemas of each schema in this set which apply to the given instance.
    # (see {Schema#inplace_applicator_schemas})
    #
    # @param instance (see Schema#inplace_applicator_schemas)
    # @return [JSI::SchemaSet]
    def inplace_applicator_schemas(instance)
      SchemaSet.new(each_inplace_applicator_schema(instance))
    end

    # yields each inplace applicator schema which applies to the given instance.
    #
    # @param instance (see Schema#inplace_applicator_schemas)
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def each_inplace_applicator_schema(instance, &block)
      return to_enum(__method__, instance) unless block

      each do |schema|
        schema.each_inplace_applicator_schema(instance, &block)
      end

      nil
    end

    # a set of child applicator subschemas of each schema in this set which apply to the child
    # of the given instance on the given token.
    # (see {Schema#child_applicator_schemas})
    #
    # @param instance (see Schema#child_applicator_schemas)
    # @return [JSI::SchemaSet]
    def child_applicator_schemas(token, instance)
      SchemaSet.new(each_child_applicator_schema(token, instance))
    end

    # yields each child applicator schema which applies to the child of
    # the given instance on the given token.
    #
    # @param (see Schema#child_applicator_schemas)
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def each_child_applicator_schema(token, instance, &block)
      return to_enum(__method__, token, instance) unless block

      each do |schema|
        schema.each_child_applicator_schema(token, instance, &block)
      end

      nil
    end

    # validates the given instance against our schemas
    #
    # @param instance [Object] the instance to validate against our schemas
    # @return [JSI::Validation::Result]
    def instance_validate(instance)
      inject(Validation::FullResult.new) do |result, schema|
        result.merge(schema.instance_validate(instance))
      end.freeze
    end

    # whether the given instance is valid against our schemas
    # @param instance [Object] the instance to validate against our schemas
    # @return [Boolean]
    def instance_valid?(instance)
      all? { |schema| schema.instance_valid?(instance) }
    end

    # @return [String]
    def inspect
      -"#{self.class}[#{map(&:inspect).join(", ")}]"
    end

    def to_s
      inspect
    end

    def pretty_print(q)
      q.text self.class.to_s
      q.text '['
      q.group(2) {
          q.breakable('')
          q.seplist(self, nil, :each) { |e|
            q.pp e
          }
      }
      q.breakable ''
      q.text ']'
    end
  end
end
