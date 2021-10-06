# frozen_string_literal: true

module JSI
  module Schema::Validation::Core
    # validates the given instance against this schema
    #
    # @private
    # @param instance_ptr [JSI::Ptr] a pointer to the instance to validate against the schema, in the instance_document
    # @param instance_document [#to_hash, #to_ary, Object] document containing the instance instance_ptr pointer points to
    # @param validate_only [Boolean] whether to return a full schema validation result or a simple, validation-only result
    # @param visited_refs [Enumerable<JSI::Schema::Ref>]
    # @return [JSI::Validation::Result]
    def internal_validate_instance(instance_ptr, instance_document, validate_only: false, visited_refs: [])
      if validate_only
        result = JSI::Validation::VALID
      else
        result = JSI::Validation::FullResult.new
      end
      result_builder = result.builder(self, instance_ptr, instance_document, validate_only, visited_refs)

      catch(:jsi_validation_result) do
        # note: true/false are not valid as schemas in draft 4; they are only values of
        # additionalProperties / additionalItems. since their behavior is undefined, though,
        # it's fine for them to behave the same as boolean schemas in later drafts.
        # I don't care about draft 4 to implement a different structuring for that.
        if schema_content == true
          # noop
        elsif schema_content == false
          result_builder.validate(false, 'instance is not valid against `false` schema')
        elsif schema_content.respond_to?(:to_hash)
          internal_validate_keywords(result_builder)
        else
          result_builder.schema_error('schema is not a boolean or a JSON object')
        end
        result
      end.freeze
    end
  end
end
