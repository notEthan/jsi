# frozen_string_literal: true

module JSI
  module Schema
    Issue = Struct.subclass(*%i(
      level
      message
      keyword
      schema
    ))

    # an issue or problem with a schema.
    #
    # when the `level` is `:error`, the schema is invalid according to its specification,
    # violating some "MUST" or "MUST NOT".
    #
    # when the `level` is `:warning`, the issue does not mean the schema is invalid, but contains something
    # that does not make sense. for example, specifying `additionalItems` without an adjacent `items` has
    # no effect (in specifications which define `additionalItems`), but is not an invalid schema.
    #
    # @!attribute level
    #   :error or :warning
    #   @return [Symbol]
    # @!attribute message
    #   a message describing the issue
    #   @return [String]
    # @!attribute keyword
    #   the keyword of the schema that has an issue
    #   @return [String]
    # @!attribute schema
    #   the schema that has an issue
    #   @return [JSI::Schema]
    class Issue
    end
  end
end
