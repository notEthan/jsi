# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Draft06
    include Schema::Application::ChildApplication
    include Schema::Application::ChildApplication::Items
    include Schema::Application::ChildApplication::Contains
    include Schema::Application::ChildApplication::Properties

    # @private
    def internal_child_applicate_keywords(token, instance, &block)
      if instance.respond_to?(:to_ary)
        # json-schema-validation 6.9.  items
        # json-schema-validation 6.10.  additionalItems
        internal_applicate_items(token, &block)

        # json-schema-validation 6.14.  contains
        internal_applicate_contains(token, instance, &block)
      end

      if instance.respond_to?(:to_hash)
        # json-schema-validation 6.18.  properties
        # json-schema-validation 6.19.  patternProperties
        # json-schema-validation 6.20.  additionalProperties
        internal_applicate_properties(token, &block)
      end
    end
  end
end
