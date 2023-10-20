# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Items
    # @private
    def internal_applicate_items(idx, instance, &block)
    if instance.respond_to?(:to_ary)
      if keyword?('items') && schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].each_index.to_a.include?(idx)
          yield subschema(['items', idx])
        elsif keyword?('additionalItems')
          yield subschema(['additionalItems'])
        end
      elsif keyword?('items')
        yield subschema(['items'])
      end
    end # if instance.respond_to?(:to_ary)
    end
  end
end
