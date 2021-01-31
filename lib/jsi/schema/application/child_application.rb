# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    autoload :Draft04, 'jsi/schema/application/child_application/draft04'
    autoload :Draft06, 'jsi/schema/application/child_application/draft06'

    # a set of child applicator subschemas of this schema which apply to the child of the given instance
    # on the given token.
    #
    # @param token [Object] the array index or object property name for the child instance
    # @param instance [Object] the instance to check any child applicators against
    # @return [JSI::SchemaSet] child application subschemas of this schema for the given token
    #   of the instance
    def child_applicator_schemas(token, instance)
        SchemaSet.build do |subschemas|
          if schema_content.respond_to?(:to_hash)

          if instance.respond_to?(:to_hash)
            apply_additional = true
            if schema_content.key?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(token)
              apply_additional = false
              subschemas << subschema(['properties', token])
            end
            if schema_content['patternProperties'].respond_to?(:to_hash)
              schema_content['patternProperties'].each_key do |pattern|
                if token.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  subschemas << subschema(['patternProperties', pattern])
                end
              end
            end
            if apply_additional && schema_content.key?('additionalProperties')
              subschemas << subschema(['additionalProperties'])
            end
          end

          if instance.respond_to?(:to_ary)
            if schema_content['items'].respond_to?(:to_ary)
              if schema_content['items'].each_index.to_a.include?(token)
                subschemas << subschema(['items', token])
              elsif schema_content.key?('additionalItems')
                subschemas << subschema(['additionalItems'])
              end
            elsif schema_content.key?('items')
              subschemas << subschema(['items'])
            end
          end

          end
        end
    end
  end
end
