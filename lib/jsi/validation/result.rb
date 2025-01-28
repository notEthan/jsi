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

        # @param subschema_ptr [JSI::Ptr, #to_ary]
        # @return [JSI::Validation::Result]
        def inplace_subschema_validate(subschema_ptr)
          subresult = schema.subschema(subschema_ptr).internal_validate_instance(
            instance_ptr,
            instance_document,
            validate_only: validate_only,
            visited_refs: visited_refs,
          )
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
          subresult
        end

        # @param results [Enumerable<Validation::Result>]
        def inplace_results_validate(*a, results: , **kw)
          results.select(&:valid?).each do |inplace_result|
            result.evaluated_tokens.merge(inplace_result.evaluated_tokens)
          end
          validate(*a, **kw,
            results: results,
          )
        end

        # @param child_results [Hash<Object, Validation::Result>] token => child result
        def child_results_validate(*a, child_results: , **kw)
          result.evaluated_tokens.merge(child_results.each_key.select { |t| child_results[t].valid? })
          validate(*a, **kw,
            results: child_results.each_value,
          )
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
            message_key,
            message_default,
            keyword: nil,
            results: Util::EMPTY_ARY,
            **additional
        )
          if !valid
            result.immediate_validation_errors << Validation::Error.new({
              message: JSI.t(message_key, default: message_default, **additional),
              keyword: keyword,
              additional: additional,
              schema: schema,
              instance_ptr: instance_ptr,
              instance_document: instance_document,
              child_errors: results.map(&:immediate_validation_errors).inject(Set[], &:merge).freeze,
            })
          end
        end
      end
    end

    class Result::Full
      def initialize
        @immediate_validation_errors = Set.new
        @evaluated_tokens = Set.new
      end

      # @return [Set<Validation::Error>]
      attr_reader(:immediate_validation_errors)

      # @yield [Validation::Error]
      def each_validation_error(&block)
        return(to_enum(__method__)) if !block_given?
        immediate_validation_errors.each do |validation_error|
          validation_error.each_validation_error(&block)
        end
        nil
      end

      # @deprecated after v0.8
      # iterating (recursively) is better done with #each_validation_error
      def validation_errors
        each_validation_error.to_set
      end

      # @return [Set]
      attr_reader(:evaluated_tokens)

      def valid?
        immediate_validation_errors.empty?
      end

      def freeze
        @immediate_validation_errors.freeze
        @evaluated_tokens.freeze
        super
      end

      def merge(result)
        raise(TypeError, "not a #{Result::Full}: #{result.pretty_inspect.chomp}") unless result.is_a?(Result::Full)
        immediate_validation_errors.merge(result.immediate_validation_errors)
        evaluated_tokens.merge(result.evaluated_tokens)
        self
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          immediate_validation_errors: immediate_validation_errors,
          evaluated_tokens: evaluated_tokens,
        }.freeze
      end
    end

    # A result indicating validation success of an instance against a schema
    class Result::Valid < Result
      # @private
      class Builder < Result::Builder
        def validate(
            valid,
            message_key,
            message_default,
            keyword: nil,
            results: Util::EMPTY_ARY,
            **additional
        )
          if !valid
            throw(:jsi_validation_result, INVALID)
          end
        end
      end
    end

    class Result::Valid
      def initialize
        @evaluated_tokens = Set.new
      end

      # @return [Set]
      attr_reader(:evaluated_tokens)

      def valid?
        true
      end

      def freeze
        @evaluated_tokens.freeze
        super
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {
          class: self.class,
          evaluated_tokens: evaluated_tokens,
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
