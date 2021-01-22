# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    autoload :Draft04, 'jsi/schema/application/inplace_application/draft04'
    autoload :Draft06, 'jsi/schema/application/inplace_application/draft06'

    # a set of inplace applicator schemas of this schema (from $ref, allOf, etc.) which apply to the
    # given instance.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param instance [Object] the instance to check any applicators against
    # @param visited_refs [Enumerable<JSI::Schema::Ref>]
    # @return [JSI::SchemaSet] matched applicator schemas
    def match_to_instance(instance, visited_refs: [])
      SchemaSet.build do |schemas|
        if schema_content.respond_to?(:to_hash)
          ref_only = false
          if schema_content['$ref'].respond_to?(:to_str)
            ref = jsi_memoize(:ref) { Schema::Ref.new(schema_content['$ref'], self) }
            unless visited_refs.include?(ref)
              ref_only = true
              schemas.merge(ref.deref_schema.match_to_instance(instance, visited_refs: visited_refs + [ref]))
            end
          end
          if !ref_only
            schemas << self
            if schema_content['allOf'].respond_to?(:to_ary)
              schema_content['allOf'].each_index do |i|
                schemas.merge(subschema(['allOf', i]).match_to_instance(instance, visited_refs: visited_refs))
              end
            end
            if schema_content['anyOf'].respond_to?(:to_ary)
              schema_content['anyOf'].each_index do |i|
                if subschema(['anyOf', i]).validate_instance(instance)
                  schemas.merge(subschema(['anyOf', i]).match_to_instance(instance, visited_refs: visited_refs))
                end
              end
            end
            if schema_content['oneOf'].respond_to?(:to_ary)
              one_i = schema_content['oneOf'].each_index.detect do |i|
                subschema(['oneOf', i]).validate_instance(instance)
              end
              if one_i
                schemas.merge(subschema(['oneOf', one_i]).match_to_instance(instance, visited_refs: visited_refs))
              end
            end
            # TODO dependencies
          end
        else
          # self is the only applicator schema if there are no keywords
          schemas << self
        end
      end
    end
  end
end
