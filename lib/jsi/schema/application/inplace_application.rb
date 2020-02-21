# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    # checks this schema for applicators ($ref, allOf, etc.) which should be applied to the given instance.
    # returns these as a Set of {JSI::Schema}s.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param other_instance [Object] the instance to check any applicators against
    # @return [Set<JSI::Schema>] matched applicator schemas
    def match_to_instance(other_instance)
      ptr = self
      schema = ptr.evaluate(document)

      Set.new.tap do |ptrs|
        if schema.respond_to?(:to_hash)
          if schema['$ref'].respond_to?(:to_str)
            ptr.deref(document) do |deref_ptr|
              ptrs.merge(deref_ptr.schema_match_ptrs_to_instance(document, instance))
            end
          else
            ptrs << ptr
          end
          if schema['allOf'].respond_to?(:to_ary)
            schema['allOf'].each_index do |i|
              ptrs.merge(ptr['allOf'][i].schema_match_ptrs_to_instance(document, instance))
            end
          end
          if schema['anyOf'].respond_to?(:to_ary)
            schema['anyOf'].each_index do |i|
              valid = ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['anyOf'][i].fragment)
              if valid
                ptrs.merge(ptr['anyOf'][i].schema_match_ptrs_to_instance(document, instance))
              end
            end
          end
          if schema['oneOf'].respond_to?(:to_ary)
            one_i = schema['oneOf'].each_index.detect do |i|
              ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['oneOf'][i].fragment)
            end
            if one_i
              ptrs.merge(ptr['oneOf'][one_i].schema_match_ptrs_to_instance(document, instance))
            end
          end
          # TODO dependencies
        else
          ptrs << ptr
        end
      end
    end
  end
end
