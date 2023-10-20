# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Draft04
    include Schema::Application::ChildApplication::Items
    include Schema::Application::ChildApplication::Properties

    # @private
    def internal_child_applicate_keywords(token, instance, &block)
        # 5.3.1.  additionalItems and items
        internal_applicate_items(token, instance, &block)

        # 5.4.4.  additionalProperties, properties and patternProperties
        internal_applicate_properties(token, instance, &block)
    end
  end
end
