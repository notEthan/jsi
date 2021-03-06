# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    # checks this schema for applicators ($ref, allOf, etc.) which should be applied to the given instance.
    # returns these as a Set of {JSI::Schema}s.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param instance [Object] the instance to check any applicators against
    # @return [JSI::SchemaSet] matched applicator schemas
    def match_to_instance(instance)
      SchemaSet.build do |schemas|
        if schema_content.respond_to?(:to_hash)
          if schema_content['$ref'].respond_to?(:to_str)
            ref = jsi_memoize(:ref) { Schema::Ref.new(schema_content['$ref'], self) }
            schemas.merge(ref.deref_schema.match_to_instance(instance))
          end
          unless ref
            schemas << self
          end
          if schema_content['allOf'].respond_to?(:to_ary)
            schema_content['allOf'].each_index do |i|
              schemas.merge(subschema(['allOf', i]).match_to_instance(instance))
            end
          end
          if schema_content['anyOf'].respond_to?(:to_ary)
            schema_content['anyOf'].each_index do |i|
              if subschema(['anyOf', i]).validate_instance(instance)
                schemas.merge(subschema(['anyOf', i]).match_to_instance(instance))
              end
            end
          end
          if schema_content['oneOf'].respond_to?(:to_ary)
            one_i = schema_content['oneOf'].each_index.detect do |i|
              subschema(['oneOf', i]).validate_instance(instance)
            end
            if one_i
              schemas.merge(subschema(['oneOf', one_i]).match_to_instance(instance))
            end
          end
          # TODO dependencies
        else
          schemas << self
        end
      end
    end
  end
end
