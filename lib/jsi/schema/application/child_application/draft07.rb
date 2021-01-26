# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Draft07
    include Schema::Application::ChildApplication
    include Schema::Application::ChildApplication::Items
    include Schema::Application::ChildApplication::Contains
    include Schema::Application::ChildApplication::Properties

    # @private
    def internal_child_applicate_keywords(token, instance, &block)
      if instance.respond_to?(:to_ary)
        # 6.4.1.  items
        # 6.4.2.  additionalItems
        internal_applicate_items(token, &block)

        # 6.4.6.  contains
        internal_applicate_contains(token, instance, &block)
      end

      if instance.respond_to?(:to_hash)
        # 6.5.4.  properties
        # 6.5.5.  patternProperties
        # 6.5.6.  additionalProperties
        internal_applicate_properties(token, &block)
      end
    end
  end
end
