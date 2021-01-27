# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    autoload :Draft04, 'jsi/schema/application/child_application/draft04'
    autoload :Draft06, 'jsi/schema/application/child_application/draft06'

    autoload :Items, 'jsi/schema/application/child_application/items'
    autoload :Properties, 'jsi/schema/application/child_application/properties'

    # a set of child applicator subschemas of this schema which apply to the child of the given instance
    # on the given token.
    #
    # @param token [Object] the array index or object property name for the child instance
    # @param instance [Object] the instance to check any child applicators against
    # @return [JSI::SchemaSet] child application subschemas of this schema for the given token
    #   of the instance
    def child_applicator_schemas(token, instance)
      SchemaSet.new(each_child_applicator_schema(token, instance))
    end

    # yields each child applicator subschema (from properties, items, etc.) which applies to the child of
    # the given instance on the given token.
    #
    # @param (see #child_applicator_schemas)
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] returns an Enumerator if invoked without a block; otherwise nil
    def each_child_applicator_schema(token, instance, &block)
      return to_enum(__method__, token, instance) unless block

          if schema_content.respond_to?(:to_hash)

          if instance.respond_to?(:to_hash)
            internal_applicate_properties(token, &block)
          end

          if instance.respond_to?(:to_ary)
            internal_applicate_items(token, &block)
          end

          end

      nil
    end
  end
end
