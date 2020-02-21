module JSI
  class SchemaValidation
    class Result
      include Util::Virtual

      # @return [Boolean] is result valid?
      def valid?
        # :nocov:
        virtual_method
        # :nocov:
      end
    end

    # a full result of validating an instance against a schema, with all validation errors, annotations, and schema errors
    class FullResult < Result
      def initialize
        @validation_errors = []
        @annotations = []
        @schema_errors = []
      end

      def validation_errors
        @validation_errors
      end

      def annotations
        @annotations
      end

      def schema_errors
        @schema_errors
      end

      def valid?
        validation_errors.empty?
      end

      def freeze
        @validation_errors.freeze
        @annotations.freeze
        @schema_errors.freeze
        super
      end
    end

    # a simple result of validating an instance against a schema, indicating only validity
    class ValidityResult < Result
      def initialize(valid)
        @valid = valid
      end

      def valid?
        @valid
      end
    end

    VALID = ValidityResult.new(true).freeze

    INVALID = ValidityResult.new(false).freeze
  end
end
