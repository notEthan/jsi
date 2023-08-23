# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Draft06
    include Schema::Application::InplaceApplication::Ref
    include Schema::Application::InplaceApplication::Dependencies
    include Schema::Application::InplaceApplication::SomeOf

    # @private
    def internal_inplace_applicate_keywords(instance, visited_refs, &block)
      # json-schema 8.  Schema references with $ref
      internal_applicate_ref(instance, visited_refs, throw_done: true, &block)

      # self is the first applicator schema if $ref has not short-circuited it
      yield self

      # json-schema-validation 6.21.  dependencies
      internal_applicate_dependencies(instance, visited_refs, &block)

      # json-schema-validation 6.26.  allOf
      # json-schema-validation 6.27.  anyOf
      # json-schema-validation 6.28.  oneOf
      internal_applicate_someOf(instance, visited_refs, &block)
    end
  end
end
