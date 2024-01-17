# frozen_string_literal: true

module JSI
  module Validation
    # a result of validating an instance against schemas which describe it.
    class Result
      Builder = Schema::Cxt.subclass(*%w(
        result
        instance_ptr
        instance_document
        validate_only
        visited_refs
      ))

      # @private
      # context to build a Validation::Result
      class Builder
        def instance
          instance_ptr.evaluate(instance_document)
        end

        def schema_issue(*_)
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
    end

    class Result
      # is the instance valid against its schemas?
      # @return [Boolean]
      def valid?
        #chkbug raise(NotImplementedError)
      end

      include Util::FingerprintHash
    end

    # a full result of validating an instance against its schemas, with each validation error
    class Result::Full < Result
      # @private
      class Builder < Result::Builder
        def validate(
            valid,
            message,
            keyword: nil,
            results: Util::EMPTY_ARY,
            **additional
        )
          results.each { |res| result.schema_issues.merge(res.schema_issues) }
          if !valid
            result.validation_errors << Validation::Error.new({
              message: message,
              keyword: keyword,
              additional: additional,
              schema: schema,
              instance_ptr: instance_ptr,
              instance_document: instance_document,
              child_errors: results.map(&:validation_errors).inject(Set[], &:merge).freeze,
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
    end

    class Result::Full
      def initialize
        @validation_errors = Set.new
        @schema_issues = Set.new
      end

      attr_reader :validation_errors
      attr_reader :schema_issues

      # @yield [Validation::Error]
      def each_validation_error(&block)
        return(to_enum(__method__)) if !block_given?
        validation_errors.each do |validation_error|
          validation_error.each_validation_error(&block)
        end
        nil
      end

      def valid?
        validation_errors.empty?
      end

      def freeze
        @schema_issues.each(&:freeze)
        @validation_errors.freeze
        @schema_issues.freeze
        super
      end

      def merge(result)
        raise(TypeError, "not a #{Result::Full}: #{result.pretty_inspect.chomp}") unless result.is_a?(Result::Full)
        validation_errors.merge(result.validation_errors)
        schema_issues.merge(result.schema_issues)
        self
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

    # A result indicating validation success of an instance against a schema
    class Result::Valid < Result
      # @private
      class Builder < Result::Builder
        def validate(
            valid,
            message,
            keyword: nil,
            results: Util::EMPTY_ARY,
            **additional
        )
          if !valid
            throw(:jsi_validation_result, INVALID)
          end
        end

        def schema_issue(*_)
          # noop
        end
      end
    end

    class Result::Valid
      def initialize
      end

      def valid?
        true
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {
          class: self.class,
        }.freeze
      end
    end

    # A result indicating validation failure of an instance against a schema
    class Result::Invalid < Result
      def valid?
        false
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        self.class
      end
    end
  end
end
