# frozen_string_literal: true

module JSI
  # a Set of JSI Schemas. always frozen.
  #
  # any schema instance is described by a set of schemas.
  class SchemaSet < ::Set
    class << self
      # builds a SchemaSet from a mutable Set which is added to by the given block
      #
      # @yield [Set] a Set to which the block may add schemas
      # @return [SchemaSet]
      def build
        mutable_set = Set.new
        yield mutable_set
        new(mutable_set)
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
      super

      not_schemas = reject { |s| s.is_a?(Schema) }
      if !not_schemas.empty?
        raise(Schema::NotASchemaError, [
          "JSI::SchemaSet initialized with non-schema objects:",
          *not_schemas.map { |ns| ns.pretty_inspect.chomp },
        ].join("\n"))
      end

      freeze
    end

    # instantiates the given instance as a JSI. its schemas are inplace applicators matched from the schemas
    # in this SchemaSet which apply to the given instance.
    #
    # @param instance [Object] the JSON Schema instance to be represented as a JSI
    # @param base_uri [nil, #to_str, Addressable::URI] for an instance document containing schemas, this is
    #   the URI of the document, whether or not the document is itself a schema.
    #   in the normal case where the document does not contain any schemas, base_uri has no effect.
    #   schemas within the document use the base_uri to resolve relative URIs.
    #   the resulting JSI may be registered with a {SchemaRegistry} (see {JSI.schema_registry}).
    # @return [JSI::Base subclass] a JSI whose instance is the given instance and whose schemas are inplace
    #   applicators matched to the instance from the schemas in this set.
    def new_jsi(instance,
        base_uri: nil
    )
      applied_schemas = inplace_applicator_schemas(instance)

      JSI::SchemaClasses.class_for_schemas(applied_schemas).new(instance,
        jsi_schema_base_uri: base_uri,
      )
    end

    # a set of inplace applicator schemas of each schema in this set which apply to the given instance.
    # (see {Schema::Application::InplaceApplication#inplace_applicator_schemas})
    #
    # @param instance (see Schema::Application::InplaceApplication#inplace_applicator_schemas)
    # @return [JSI::SchemaSet]
    def inplace_applicator_schemas(instance)
      SchemaSet.new(each_inplace_applicator_schema(instance))
    end

    # yields each inplace applicator schema which applies to the given instance.
    #
    # @param instance (see Schema::Application::InplaceApplication#inplace_applicator_schemas)
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] returns an Enumerator if invoked without a block; otherwise nil
    def each_inplace_applicator_schema(instance, &block)
      return to_enum(__method__, instance) unless block

      each do |schema|
        schema.each_inplace_applicator_schema(instance, &block)
      end

      nil
    end

    # validates the given instance against our schemas
    #
    # @param instance [Object] the instance to validate against our schemas
    # @return [JSI::Validation::Result]
    def instance_validate(instance)
      results = map { |schema| schema.instance_validate(instance) }
      results.inject(Validation::FullResult.new, &:merge).freeze
    end

    # @param instance [Object] the instance to validate against our schemas
    # @return [Boolean] whether the given instance is valid against our schemas
    def instance_valid?(instance)
      all? { |schema| schema.instance_valid?(instance) }
    end

    def inspect
      "#{self.class}[#{map(&:inspect).join(", ")}]"
    end

    def pretty_print(q)
      q.text self.class.to_s
      q.text '['
      q.group_sub {
        q.nest(2) {
          q.breakable('')
          q.seplist(self, nil, :each) { |e|
            q.pp e
          }
        }
      }
      q.breakable ''
      q.text ']'
    end
  end
end
