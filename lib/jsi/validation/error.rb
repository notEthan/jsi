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
    #   @return [String] a message describing the error
    # @!attribute keyword
    #   @return [String] the keyword of the schema which failed to validate.
    #   this may be absent if the error is not from a schema keyword (i.e, `false` schema).
    # @!attribute schema
    #   @return [JSI::Schema] the schema against which the instance failed to validate
    # @!attribute instance_ptr
    #   @return [JSI::Ptr] pointer to the instance in instance_document
    # @!attribute instance_document
    #   @return [Object] document containing the instance at instance_ptr
    class Error
    end
  end
end
