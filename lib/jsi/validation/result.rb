# frozen_string_literal: true

module JSI
  module Validation
    # a result of validating an instance against schemas which describe it.
    # virtual base class.
    class Result
      include Util::Virtual

      # @return [Boolean] is the instance valid against its schemas?
      def valid?
        # :nocov:
        virtual_method
        # :nocov:
      end

      include Util::FingerprintHash
    end

    # a full result of validating an instance against its schemas, with each validation error
    class FullResult < Result
      def initialize
        @validation_errors = Set.new
        @schema_issues = Set.new
      end

      attr_reader :validation_errors
      attr_reader :schema_issues

      def valid?
        validation_errors.empty?
      end

      def freeze
        @validation_errors.each(&:freeze)
        @schema_issues.each(&:freeze)
        @validation_errors.freeze
        @schema_issues.freeze
        super
      end

      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          validation_errors: validation_errors,
          schema_issues: schema_issues,
        }
      end
    end

    # a result indicating only whether an instance is valid against its schemas
    class ValidityResult < Result
      def initialize(valid)
        @valid = valid
      end

      def valid?
        @valid
      end

      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          valid: valid?,
        }
      end
    end
  end
end
