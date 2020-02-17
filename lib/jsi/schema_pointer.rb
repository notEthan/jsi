# frozen_string_literal: true

module JSI
  class SchemaPointer < JSI::JSON::Pointer
    autoload :Draft04, 'jsi/schema_pointer/draft04'
    autoload :Draft06, 'jsi/schema_pointer/draft06'
    autoload :Draft201909, 'jsi/schema_pointer/draft201909'

    # given this Pointer points to a schema in the given document, returns a set of pointers
    # to subschemas of that schema for the given property name.
    #
    # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
    # @param property_name [Object] the property name for which to find a subschema
    # @return [Set<JSI::JSON::Pointer>] pointers to subschemas
    def schema_subschema_ptrs_for_property_name(document, property_name)
      ptr = self
      schema = ptr.evaluate(document)
      Set.new.tap do |ptrs|
        if schema.respond_to?(:to_hash)
          apply_additional = true
          if schema.key?('properties') && schema['properties'].respond_to?(:to_hash) && schema['properties'].key?(property_name)
            apply_additional = false
            ptrs << ptr['properties'][property_name]
          end
          if schema['patternProperties'].respond_to?(:to_hash)
            schema['patternProperties'].each_key do |pattern|
              if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                apply_additional = false
                ptrs << ptr['patternProperties'][pattern]
              end
            end
          end
          if apply_additional && schema.key?('additionalProperties')
            ptrs << ptr['additionalProperties']
          end
        end
      end.map { |ptr| ptr.as(self.class) }
    end

    # given this Pointer points to a schema in the given document, returns a set of pointers
    # to subschemas of that schema for the given array index.
    #
    # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
    # @param idx [Object] the array index for which to find subschemas
    # @return [Set<JSI::JSON::Pointer>] pointers to subschemas
    def schema_subschema_ptrs_for_index(document, idx)
      ptr = self
      schema = ptr.evaluate(document)
      Set.new.tap do |ptrs|
        if schema.respond_to?(:to_hash)
          if schema['items'].respond_to?(:to_ary)
            if schema['items'].each_index.to_a.include?(idx)
              ptrs << ptr['items'][idx]
            elsif schema.key?('additionalItems')
              ptrs << ptr['additionalItems']
            end
          elsif schema.key?('items')
            ptrs << ptr['items']
          end
        end
      end.map { |ptr| ptr.as(self.class) }
    end

    # given this Pointer points to a schema in the given document, this matches any
    # applicators of the schema (oneOf, anyOf, allOf, $ref) which should be applied
    # and returns them as a set of pointers.
    #
    # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
    # @param instance [Object] the instance to check any applicators against
    # @param ignore [Enumerable<JSI::JSON::Pointer>] a Set of Pointers which have already been checked to
    #   the schema. used to prevent infinite recursion on invalid self-referential schemas.
    # @return [JSI::JSON::Pointer] either a pointer to a *Of subschema in the document,
    #   or self if no other subschema was matched
    def schema_match_ptrs_to_instance(document, instance, ignore: [])
      return(Set[self]) if ignore.include?(self)

      Set.new.tap do |ptrs|
        ptr = self
        schema = ptr.evaluate(document)

        if schema.respond_to?(:to_hash)
          if schema['$ref'].respond_to?(:to_str) || schema['$recursiveRef'].respond_to?(:to_str)
            ptr.deref(document) do |deref_ptr|
              ptrs.merge(deref_ptr.schema_match_ptrs_to_instance(document, instance, ignore: ignore + [self]))
            end
          else
            ptrs << ptr
          end
          if schema['allOf'].respond_to?(:to_ary)
            schema['allOf'].each_index do |i|
              ptrs.merge(ptr['allOf'][i, as: self.class].schema_match_ptrs_to_instance(document, instance, ignore: ignore))
            end
          end
          if schema['anyOf'].respond_to?(:to_ary)
            schema['anyOf'].each_index do |i|
              valid = ptr['anyOf'][i, as: self.class].schema_validate(document, JSI::JSON::Pointer[], instance, validate_only: true).valid?
              if valid
                ptrs.merge(ptr['anyOf'][i, as: self.class].schema_match_ptrs_to_instance(document, instance, ignore: ignore))
              end
            end
          end
          if schema['oneOf'].respond_to?(:to_ary)
            one_i = schema['oneOf'].each_index.detect do |i|
              ptr['oneOf'][i, as: self.class].schema_validate(document, JSI::JSON::Pointer[], instance, validate_only: true).valid?
            end
            if one_i
              ptrs.merge(ptr['oneOf'][one_i, as: self.class].schema_match_ptrs_to_instance(document, instance, ignore: ignore))
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
