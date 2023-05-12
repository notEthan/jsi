# frozen_string_literal: true

module JSI
  module Validation
    # a result of validating an instance against schemas which describe it.
    # virtual base class.
    class Result
      include Util::Virtual

      Builder = Util::AttrStruct[*%w(
        result
        schema
        instance_ptr
        instance_document
        validate_only
        visited_refs
      )]

      # @private
      # a structure used to build a Result. virtual base class.
      class Builder
        def instance
          instance_ptr.evaluate(instance_document)
        end

        def schema_issue(*_)
          virtual_method
        end

        def schema_error(message, keyword = nil)
          schema_issue(:error, message, keyword)
        end

        def schema_warning(message, keyword = nil)
          schema_issue(:warning, message, keyword)
        end

        # @param subschema_ptr [JSI::Ptr, #to_ary]
        # @return [JSI::Validation::Result]
        def inplace_subschema_validate(subschema_ptr)
          subresult = schema.subschema(subschema_ptr).internal_validate_instance(
            instance_ptr,
            instance_document,
            validate_only: validate_only,
            visited_refs: visited_refs,
          )
          merge_schema_issues(subresult)
          subresult
        end

        # @param instance_child_token [String, Integer]
        # @param subschema_ptr [JSI::Ptr, #to_ary]
        # @return [JSI::Validation::Result]
        def child_subschema_validate(instance_child_token, subschema_ptr)
          subresult = schema.subschema(subschema_ptr).internal_validate_instance(
            instance_ptr[instance_child_token],
            instance_document,
            validate_only: validate_only,
          )
          merge_schema_issues(subresult)
          subresult
        end

        # @param other_result [JSI::Validation::Result]
        # @return [void]
        def merge_schema_issues(other_result)
          unless validate_only
            # schema_issues are always merged from subschema results (not depending on validation results)
            result.schema_issues.merge(other_result.schema_issues)
          end
          nil
        end
      end

      def builder(schema, instance_ptr, instance_document, validate_only, visited_refs)
        self.class::Builder.new(
          result: self,
          schema: schema,
          instance_ptr: instance_ptr,
          instance_document: instance_document,
          validate_only: validate_only,
          visited_refs: visited_refs,
        )
      end

      # is the instance valid against its schemas?
      # @return [Boolean]
      def valid?
        # :nocov:
        virtual_method
        # :nocov:
      end

      include Util::FingerprintHash
    end

    # a full result of validating an instance against its schemas, with each validation error
    class FullResult < Result
      # @private
      class Builder < Result::Builder
        def validate(
            valid,
            message,
            keyword: nil,
            results: []
        )
          results.each { |res| result.schema_issues.merge(res.schema_issues) }
          if !valid
            results.each { |res| result.validation_errors.merge(res.validation_errors) }
            result.validation_errors << Validation::Error.new({
              message: message,
              keyword: keyword,
              schema: schema,
              instance_ptr: instance_ptr,
              instance_document: instance_document,
            })
          end
        end

        def schema_issue(level, message, keyword = nil)
          result.schema_issues << Schema::Issue.new({
            level: level,
            message: message,
            keyword: keyword,
            schema: schema,
          })
        end
      end

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

      def merge(result)
        unless result.is_a?(FullResult)
          raise(TypeError, "not a #{FullResult.name}: #{result.pretty_inspect.chomp}")
        end
        validation_errors.merge(result.validation_errors)
        schema_issues.merge(result.schema_issues)
        self
      end

      def +(result)
        FullResult.new.merge(self).merge(result)
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          validation_errors: validation_errors,
          schema_issues: schema_issues,
        }.freeze
      end
    end

    # a result indicating only whether an instance is valid against its schemas
    class ValidityResult < Result
      # @private
      class Builder < Result::Builder
        def validate(
            valid,
            message,
            keyword: nil,
            results: []
        )
          if !valid
            throw(:jsi_validation_result, INVALID)
          end
        end

        def schema_issue(*_)
          # noop
        end
      end

      def initialize(valid)
        @valid = valid
      end

      def valid?
        @valid
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          valid: valid?,
        }.freeze
      end
    end
  end
end
