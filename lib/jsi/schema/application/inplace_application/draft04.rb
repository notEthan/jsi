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

      yield self

      internal_applicate_someOf(instance, visited_refs, &block)

      # TODO dependencies
    end
  end
end
