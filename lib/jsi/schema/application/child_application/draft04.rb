# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Draft04
    include Schema::Application::ChildApplication::Items
    include Schema::Application::ChildApplication::Properties

    # @private
    def internal_child_applicate_keywords(token, instance, &block)
      if instance.respond_to?(:to_ary)
        # 5.3.1.  additionalItems and items
        internal_applicate_items(token, &block)
      end

      if instance.respond_to?(:to_hash)
        # 5.4.4.  additionalProperties, properties and patternProperties
        internal_applicate_properties(token, &block)
      end
    end
  end
end
