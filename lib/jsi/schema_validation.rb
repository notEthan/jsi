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

    class Result
      class Builder
        def initialize(schema_document, instance_ptr, instance_document, validate_only, return_proc)
          @schema_document = schema_document
          @instance_ptr = instance_ptr
          @instance_document = instance_document
          @validate_only = validate_only
          @return_proc = return_proc
        end
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

      def merge(result)
        unless result.is_a?(FullResult)
          raise(TypeError, "not a JSI::SchemaValidation::FullResult: #{result.pretty_inspect.chomp}")
        end
        validation_errors.merge(result.validation_errors)
        annotations.merge(result.annotations)
        schema_errors.merge(result.schema_errors)
        self
      end

      def +(result)
        FullResult.new.merge(self).merge(result)
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
