# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Items
    # @private
    def internal_applicate_items(idx, &block)
      if schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].each_index.to_a.include?(idx)
          yield subschema(['items', idx])
        elsif schema_content.key?('additionalItems')
          yield subschema(['additionalItems'])
        end
      elsif schema_content.key?('items')
        yield subschema(['items'])
      end
    end
  end
end
