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
  end
end
