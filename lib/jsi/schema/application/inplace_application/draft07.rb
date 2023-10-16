# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Draft07
    include Schema::Application::InplaceApplication::Ref
    include Schema::Application::InplaceApplication::Dependencies
    include Schema::Application::InplaceApplication::IfThenElse
    include Schema::Application::InplaceApplication::SomeOf

    # @private
    def internal_inplace_applicate_keywords(instance, visited_refs, &block)
      # json-schema 8.  Schema references with $ref
      internal_applicate_ref(instance, visited_refs, throw_done: true, &block)

      # self is the first applicator schema if $ref has not short-circuited it
      block.call(self)

      # 6.5.7.  dependencies
      internal_applicate_dependencies(instance, visited_refs, &block)

      # 6.6.1.  if
      # 6.6.2.  then
      # 6.6.3.  else
      internal_applicate_ifthenelse(instance, visited_refs, &block)

      # 6.7.1.  allOf
      # 6.7.2.  anyOf
      # 6.7.3.  oneOf
      internal_applicate_someOf(instance, visited_refs, &block)
    end
  end
end
