# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Draft04
    include Schema::Application::InplaceApplication
    include Schema::Application::InplaceApplication::Ref
    include Schema::Application::InplaceApplication::Dependencies
    include Schema::Application::InplaceApplication::SomeOf

    # @private
    def internal_inplace_applicate_keywords(instance, visited_refs, &block)
      internal_applicate_ref(instance, visited_refs, throw_done: true, &block)

      # self is the first applicator schema if $ref has not short-circuited it
      yield self

      # 5.4.5.  dependencies
      internal_applicate_dependencies(instance, visited_refs, &block)

      # 5.5.3.  allOf
      # 5.5.4.  anyOf
      # 5.5.5.  oneOf
      internal_applicate_someOf(instance, visited_refs, &block)
    end
  end
end
