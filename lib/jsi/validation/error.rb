# frozen_string_literal: true

module JSI
  module Validation
    Error = Util::AttrStruct[*%w(
      message
      keyword
      additional
      schema
      instance_ptr
      instance_document
      child_errors
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
    # @!attribute additional
    #   additional contextual information about the error
    #   @return [Hash]
    # @!attribute schema
    #   the schema against which the instance failed to validate
    #   @return [JSI::Schema]
    # @!attribute instance_ptr
    #   pointer to the instance in instance_document
    #   @return [JSI::Ptr]
    # @!attribute instance_document
    #   document containing the instance at instance_ptr
    #   @return [Object]
    # @!attribute child_errors
    #   @return [Set<Validation::Error>]
    class Error
      def initialize(attributes = {})
        super
        freeze
      end

      # @yield [Validation::Error]
      def each_validation_error(&block)
        return(to_enum(__method__)) if !block_given?
        child_errors.each { |child_error| child_error.each_validation_error(&block) }
        yield(self)
        nil
      end
    end
  end
end
