# frozen_string_literal: true

module JSI
  module Validation
    Error = Util::AttrStruct[*%w(
      message
      keyword
      schema
      instance_ptr
      instance_document
    )]

    # a validation error of a schema instance against a schema
    #
    # @!attribute message
    #   a message describing the error
    #   @return [String]
    # @!attribute keyword
    #   the keyword of the schema which failed to validate.
    #   this may be absent if the error is not from a schema keyword (i.e, `false` schema).
    #   @return [String]
    # @!attribute schema
    #   the schema against which the instance failed to validate
    #   @return [JSI::Schema]
    # @!attribute instance_ptr
    #   pointer to the instance in instance_document
    #   @return [JSI::Ptr]
    # @!attribute instance_document
    #   document containing the instance at instance_ptr
    #   @return [Object]
    class Error
    end
  end
end
