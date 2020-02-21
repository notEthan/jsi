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
        @validation_errors = Set.new
        @annotations = Set.new
        @schema_errors = Set.new
      end

      attr_accessor :validation_errors
      attr_accessor :annotations
      attr_accessor :schema_errors

      def valid?
        validation_errors.empty?
      end

      def freeze
        @validation_errors.each(&:freeze)
        @annotations.each(&:freeze)
        @schema_errors.each(&:freeze)
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
