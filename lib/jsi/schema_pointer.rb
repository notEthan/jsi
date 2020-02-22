# frozen_string_literal: true

module JSI
  class SchemaPointer < JSI::JSON::Pointer
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
      end.map(&:as_schema_ptr)
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
      end.map(&:as_schema_ptr)
    end

    # given this Pointer points to a schema in the given document, this matches any
    # applicators of the schema (oneOf, anyOf, allOf, $ref) which should be applied
    # and returns them as a set of pointers.
    #
    # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
    # @param instance [Object] the instance to check any applicators against
    # @return [JSI::JSON::Pointer] either a pointer to a *Of subschema in the document,
    #   or self if no other subschema was matched
    def schema_match_ptrs_to_instance(document, instance)
      ptr = self
      schema = ptr.evaluate(document)

      Set.new.tap do |ptrs|
        if schema.respond_to?(:to_hash)
          if schema['$ref'].respond_to?(:to_str)
            ptr.deref(document) do |deref_ptr|
              ptrs.merge(deref_ptr.as_schema_ptr.schema_match_ptrs_to_instance(document, instance))
            end
          else
            ptrs << ptr
          end
          if schema['allOf'].respond_to?(:to_ary)
            schema['allOf'].each_index do |i|
              ptrs.merge(ptr['allOf'][i].as_schema_ptr.schema_match_ptrs_to_instance(document, instance))
            end
          end
          if schema['anyOf'].respond_to?(:to_ary)
            schema['anyOf'].each_index do |i|
              valid = ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['anyOf'][i].fragment)
              if valid
                ptrs.merge(ptr['anyOf'][i].as_schema_ptr.schema_match_ptrs_to_instance(document, instance))
              end
            end
          end
          if schema['oneOf'].respond_to?(:to_ary)
            one_i = schema['oneOf'].each_index.detect do |i|
              ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['oneOf'][i].fragment)
            end
            if one_i
              ptrs.merge(ptr['oneOf'][one_i].as_schema_ptr.schema_match_ptrs_to_instance(document, instance))
            end
          end
          # TODO dependencies
        end
      end.map(&:as_schema_ptr)
    end

    # given this Pointer points to a schema in the given schema_document, this validates the given instance
    # against the schema.
    #
    # @param schema_document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
    # @param instance_ptr [JSI::JSON::Pointer] a pointer to the instance to validate against the schema, in the instance_document
    # @param instance_document [#to_hash, #to_ary, Object] document containing the instance instance_ptr pointer points to
    # @param validate_only [Boolean] whether to return a SchemaApplicationResult or a SchemaValidResult
    # @return [SchemaApplicationResult, SchemaValidResult]
    def schema_validate(schema_document, instance_ptr, instance_document, validate_only: false)
      schema_ptr = self
      schema = schema_ptr.evaluate(schema_document)
      instance = instance_ptr.evaluate(instance_document)

      if validate_only
        result = JSI::SchemaValidation::VALID
        annotate = Util::NOOP
        schema_error = Util::NOOP
      else
        result = JSI::SchemaValidation::FullResult.new
        annotate = proc do |keyword, annotation|
          result.annotations << {
            keyword: keyword,
            annotation: annotation,
            schema_ptr: schema_ptr,
            schema_document: schema_document,
            instance_ptr: instance_ptr,
            instance_document: instance_document,
          }
        end

        schema_error = proc do |message, keyword = nil|
          result.schema_errors << {
            message: message,
            keyword: keyword,
            schema_ptr: schema_ptr,
            schema_document: schema_document,
          }
        end
      end

      validate = proc do |valid, message, keyword = nil, results: nil|
        unless valid
          if validate_only
            return JSI::SchemaValidation::INVALID
          else
            result.validation_errors << {
              message: message,
              keyword: keyword,
              schema_ptr: schema_ptr,
              schema_document: schema_document,
              instance_ptr: instance_ptr,
              instance_document: instance_document,
            }
          end
        end
      end
      if validate_only
        result = JSI::SchemaValidation::VALID
        annotate = Util::NOOP
        schema_error = Util::NOOP
      else
        result = JSI::SchemaValidation::FullResult.new
        annotate = proc do |keyword, annotation|
          result.annotations << {
            keyword: keyword,
            annotation: annotation,
            schema_ptr: schema_ptr,
            schema_document: schema_document,
            instance_ptr: instance_ptr,
            instance_document: instance_document,
          }
        end

        schema_error = proc do |message, keyword = nil|
          result.schema_errors << {
            message: message,
            keyword: keyword,
            schema_ptr: schema_ptr,
            schema_document: schema_document,
          }
        end
      end

      if schema == true
        # (noop)
      elsif schema == false
        validate.(false, "false schema")
      elsif schema.respond_to?(:to_hash)
        # 6.1. Validation Keywords for Any Instance Type
        if schema.key?('type') # 6.1.1. type
          keyword = 'type'
          value = schema[keyword]
          # The value of this keyword MUST be either a string or an array. If it is an array, elements of
          # the array MUST be strings and MUST be unique.
          if value.respond_to?(:to_str) || value.respond_to?(:to_ary)
            types = value.respond_to?(:to_str) ? [value] : value
            matched_type = types.each_with_index.any? do |type, i|
              if type.respond_to?(:to_str)
                case type.to_str
                when 'null'
                  instance == nil
                when 'boolean'
                  instance == true || instance == false
                when 'object'
                  instance.respond_to?(:to_hash)
                when 'array'
                  instance.respond_to?(:to_ary)
                when 'string'
                  instance.respond_to?(:to_str)
                when 'number'
                  instance.is_a?(Numeric)
                when 'integer'
                  instance.is_a?(Integer) || (instance.is_a?(Numeric) && instance % 1.0 == 0.0)
                else
                  schema_error.("`type` must be one of: null, boolean, object, array, string, number, or integer", keyword)
                end
              else
                schema_error.("`type` is not a string at index #{i}", keyword)
              end
            end
            validate.(matched_type, 'instance type does not match `type` value', keyword)
          else
            schema_error.('`type` is not a string or array', keyword)
          end
        end

        # 6.1.2. enum
        if schema.key?('enum')
          keyword = 'enum'
          value = schema[keyword]
          # The value of this keyword MUST be an array. This array SHOULD have at least one element.
          # Elements in the array SHOULD be unique.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if its value is equal to one of the
            # elements in this keyword's array value.
            validate.(value.include?(instance), 'instance is not equal to any `enum` value', keyword)
          else
            schema_error.('`enum` is not an array', keyword)
          end
        end

        # 6.1.3. const
        if schema.key?('const')
          keyword = 'const'
          value = schema[keyword]
          # The value of this keyword MAY be of any type, including null.
          # An instance validates successfully against this keyword if its value is equal to the value of
          # the keyword.
          validate.(instance == value, 'instance is not equal to `const` value', keyword)
        end

        # 6.2. Validation Keywords for Numeric Instances (number and integer)

        # 6.2.1. multipleOf
        if schema.key?('multipleOf')
          keyword = 'multipleOf'
          value = schema[keyword]
          # The value of "multipleOf" MUST be a number, strictly greater than 0.
          if value.is_a?(Numeric) && value > 0
            # A numeric instance is valid only if division by this keyword's value results in an integer.
            if instance.is_a?(Numeric)
              validate.(instance % value == 0, 'instance is not a multiple of `multipleOf` value', keyword)
            end
          else
            schema_error.('`multipleOf` is not a number greater than 0', keyword)
          end
        end

        # 6.2.2. maximum
        if schema.key?('maximum')
          keyword = 'maximum'
          value = schema[keyword]
          # The value of "maximum" MUST be a number, representing an inclusive upper limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then this keyword validates only if the instance is less than
            # or exactly equal to "maximum".
            if instance.is_a?(Numeric)
              validate.(instance <= value, 'instance is not less than or equal to `maximum` value', keyword)
            end
          else
            schema_error.('`maximum` is not a number', keyword)
          end
        end

        # 6.2.3. exclusiveMaximum
        if schema.key?('exclusiveMaximum')
          keyword = 'exclusiveMaximum'
          value = schema[keyword]
          # The value of "exclusiveMaximum" MUST be number, representing an exclusive upper limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then the instance is valid only if it has a value strictly less than (not equal to) "exclusiveMaximum".
            if instance.is_a?(Numeric)
              validate.(instance < value, 'instance is not less than `exclusiveMaximum` value', keyword)
            end
          else
            schema_error.('`exclusiveMaximum` is not a number', keyword)
          end
        end

        # 6.2.4. minimum
        if schema.key?('minimum')
          keyword = 'minimum'
          value = schema[keyword]
          # The value of "minimum" MUST be a number, representing an inclusive lower limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then this keyword validates only if the instance is greater than or exactly equal to "minimum".
            if instance.is_a?(Numeric)
              validate.(instance >= value, 'instance is not greater than or equal to `minimum` value', keyword)
            end
          else
            schema_error.('`minimum` is not a number', keyword)
          end
        end

        # 6.2.5. exclusiveMinimum
        if schema.key?('exclusiveMinimum')
          keyword = 'exclusiveMinimum'
          value = schema[keyword]
          # The value of "exclusiveMinimum" MUST be number, representing an exclusive lower limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then the instance is valid only if it has a value strictly greater than (not equal to) "exclusiveMinimum".
            if instance.is_a?(Numeric)
              validate.(instance > value, 'instance is not greater than `exclusiveMinimum` value', keyword)
            end
          else
            schema_error.('`exclusiveMinimum` is not a number', keyword)
          end
        end

        # 6.3. Validation Keywords for Strings

        # 6.3.1. maxLength
        if schema.key?('maxLength')
          keyword = 'maxLength'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_str)
              # A string instance is valid against this keyword if its length is less than, or equal to, the value of this keyword.
              validate.(instance.to_str.length <= value, 'instance string length is not less than or equal to `maxLength` value', keyword)
            end
          else
            schema_error.('`maxLength` is not a non-negative integer', keyword)
          end
        end

        # 6.3.2. minLength
        if schema.key?('minLength')
          keyword = 'minLength'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_str)
              # A string instance is valid against this keyword if its length is greater than, or equal to, the value of this keyword.
              validate.(instance.to_str.length >= value, 'instance string length is not greater than or equal to `minLength` value', keyword)
            end
          else
            schema_error.('`minLength` is not a non-negative integer', keyword)
          end
        end

        # 6.3.3. pattern
        if schema.key?('pattern')
          keyword = 'pattern'
          value = schema[keyword]
          # The value of this keyword MUST be a string.
          if value.respond_to?(:to_str)
            if instance.respond_to?(:to_str)
              begin
                # This string SHOULD be a valid regular expression, according to the ECMA 262 regular expression dialect.
                # TODO
                regexp = Regexp.new(value)
                # A string instance is considered valid if the regular expression matches the instance successfully. Recall: regular expressions are not implicitly anchored.
                validate.(regexp.match(instance), 'instance string does not match `pattern` regular expression value', keyword)
              rescue RegexpError => e
                schema_error.("`pattern` is not a valid regular expression: #{e.message}", keyword)
              end
            end
          else
            schema_error.('`pattern` is not a string', keyword)
          end
        end

        # 6.4. Validation Keywords for Arrays

        # 6.4.1. maxItems
        if schema.key?('maxItems')
          keyword = 'maxItems'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "maxItems" if its size is less than, or equal to, the value of this keyword.
              validate.(instance.to_ary.size <= value, 'instance array size is not less than or equal to `maxItems` value', keyword)
            end
          else
            schema_error.('`maxItems` is not a non-negative integer', keyword)
          end
        end

        # 6.4.2. minItems
        if schema.key?('minItems')
          keyword = 'minItems'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "minItems" if its size is greater than, or equal to, the value of this keyword.
              validate.(instance.to_ary.size >= value, 'instance array size is not greater than or equal to `minItems` value', keyword)
            end
          else
            schema_error.('`minItems` is not a non-negative integer', keyword)
          end
        end

        # 6.4.3. uniqueItems
        if schema.key?('uniqueItems')
          keyword = 'uniqueItems'
          value = schema[keyword]
          # The value of this keyword MUST be a boolean.
          if value == false
            # If this keyword has boolean value false, the instance validates successfully.
            # (noop)
          elsif value == true
            if instance.respond_to?(:to_ary)
              # If it has boolean value true, the instance validates successfully if all of its elements are unique.
              validate.(instance.uniq.size == instance.size, "instance array items' uniqueness does not match `uniqueItems` value", keyword)
            end
          else
            schema_error.('`uniqueItems` is not a boolean', keyword)
          end
        end

        # 6.4.4. maxContains
        if schema.key?('maxContains')
          keyword = 'maxContains'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "maxContains" if the number of elements that are valid
              # against the schema for "contains" is less than, or equal to, the value of this keyword.
              results = instance.each_index.map do |idx|
                schema_ptr['contains'].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
              end
              validate.(results.select(&:valid?).size <= value, 'instance array contains more items valid against the `contains` schema than the `maxContains` value', keyword, results: results)
            end
          else
            schema_error.('`maxContains` is not a non-negative integer', keyword)
          end
        end

        # 6.4.5. minContains
        if schema.key?('minContains')
          keyword = 'minContains'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "minContains" if the number of elements that are valid
              # against the schema for "contains" is greater than, or equal to, the value of this keyword.
              results = instance.each_index.map do |idx|
                schema_ptr['contains'].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
              end
              validate.(results.select(&:valid?).size >= value, 'instance array contains fewer items valid against the `contains` schema than the `minContains` value', keyword, results: results)
            end
          else
            schema_error.('`minContains` is not a non-negative integer', keyword)
          end
        end

        # 6.5. Validation Keywords for Objects

        # 6.5.1. maxProperties
        if schema.key?('maxProperties')
          keyword = 'maxProperties'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_hash)
              # An object instance is valid against "maxProperties" if its number of properties is less than, or equal to, the value of this keyword.
              validate.(instance.size <= value, 'instance object contains more properties than the `maxProperties` value', keyword)
            end
          else
            schema_error.('`maxProperties` is not a non-negative integer', keyword)
          end
        end

        # 6.5.2. minProperties
        if schema.key?('minProperties')
          keyword = 'minProperties'
          value = schema[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_hash)
              # An object instance is valid against "minProperties" if its number of properties is greater than, or equal to, the value of this keyword.
              validate.(instance.size >= value, 'instance object contains fewer properties than the `minProperties` value', keyword)
            end
          else
            schema_error.('`minProperties` is not a non-negative integer', keyword)
          end
        end

        # 6.5.3. required
        if schema.key?('required')
          keyword = 'required'
          value = schema[keyword]
          # The value of this keyword MUST be an array. Elements of this array, if any, MUST be strings, and MUST be unique.
          if value.respond_to?(:to_ary)
            if instance.respond_to?(:to_hash)
              # An object instance is valid against this keyword if every item in the array is the name of a property in the instance.
              missing_required = value.reject { |property_name| instance.key?(property_name) }
              # TODO include missing required property names in the validation error
              validate.(missing_required.empty?, 'instance object does not contain all property names specified by the `required` value', keyword)
x                validate.(missing_required.empty?, 'instance object does not contain all property names specified by the `required` value', keyword, missing_required: missing_required)
            end
          else
            schema_error.('`required` is not an array', keyword)
          end
        end

        # 6.5.4. dependentRequired
        if schema.key?('dependentRequired')
          keyword = 'dependentRequired'
          value = schema[keyword]
          # The value of this keyword MUST be an object. Properties in this object, if any, MUST be arrays. Elements in each array, if any, MUST be strings, and MUST be unique.
          if value.respond_to?(:to_hash) && value.values.all? { |names| names.respond_to?(:to_ary) }
            if instance.respond_to?(:to_hash)
              # This keyword specifies properties that are required if a specific other property is
              # present. Their requirement is dependent on the presence of the other property.
              #
              # Validation succeeds if, for each name that appears in both the instance and as a name
              # within this keyword's value, every item in the corresponding array is also the name of
              # a property in the instance.
              missing_dependent_required = {}
              value.each do |property_name, dependent_property_names|
                if instance.key?(property_name)
                  missing_required = dependent_property_names.reject { |name| instance.key?(name) }
                  unless missing_required.empty?
                    missing_dependent_required[property_name] = missing_required
                  end
                end
              end
              # TODO include missing dependent required property names in the validation error
              validate.(missing_dependent_required.empty?, 'instance object does not contain all dependent required property names specified by the `dependentRequired` value', keyword)
x                validate.(missing_dependent_required.empty?, 'instance object does not contain all dependent required property names specified by the `dependentRequired` value', keyword, missing_dependent_required: missing_dependent_required)
            end
          else
            schema_error.('`dependentRequired` is not an object whose properties are arrays', keyword)
          end
        end

        # 9.2.  Keywords for Applying Subschemas in Place

        # 9.2.1.  Keywords for Applying Subschemas With Boolean Logic

        # 9.2.1.1. allOf
        if schema.key?('allOf')
          keyword = 'allOf'
          value = schema[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against all schemas defined by this keyword's value.
            allOf_results = value.each_index.map do |idx|
              schema_ptr['allOf'][idx].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
            end
            validate.(allOf_results.all?(&:valid?), 'instance did not validate against all schemas defined by `allOf` value', keyword, results: allOf_results)
          else
            schema_error.('`allOf` is not an array', keyword)
          end
        end

        # 9.2.1.2. anyOf
        if schema.key?('anyOf')
          keyword = 'anyOf'
          value = schema[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against at least one schema defined by this keyword's value. Note that when annotations are being collected, all subschemas MUST be examined so that annotations are collected from each subschema that validates successfully.
            anyOf_results = value.each_index.map do |idx|
              schema_ptr['anyOf'][idx].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
            end
            validate.(anyOf_results.any?(&:valid?), 'instance did not validate against any schemas defined by `anyOf` value', keyword, results: anyOf_results)
          else
            schema_error.('`anyOf` is not an array', keyword)
          end
        end

        # 9.2.1.3. oneOf
        if schema.key?('oneOf')
          keyword = 'oneOf'
          value = schema[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against exactly one schema defined by this keyword's value.
            oneOf_results = value.each_index.map do |idx|
              schema_ptr['oneOf'][idx].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
            end
            if oneOf_results.none?(&:valid?)
              validate.(false, 'instance did not validate against any schemas defined by `oneOf` value', keyword, results: oneOf_results)
            else
              validate.(oneOf_results.select(&:valid?).size == 1, 'instance validated against multiple schemas defined by `oneOf` value', keyword, results: oneOf_results)
            end
          else
            schema_error.('`oneOf` is not an array', keyword)
          end
        end

        # 9.2.1.4. not
        if schema.key?('not')
          keyword = 'not'
          value = schema[keyword]
          # This keyword's value MUST be a valid JSON Schema.
          # An instance is valid against this keyword if it fails to validate successfully against the schema defined by this keyword.
          not_valid = schema_ptr['not'].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: true).valid?
          validate.(!not_valid, 'instance validated against the schema defined by `not` value', keyword)
        end

        # 9.2.2. Keywords for Applying Subschemas Conditionally

        # 9.2.2.1. if
        if schema.key?('if')
          keyword = 'if'
          value = schema[keyword]

          # This keyword's value MUST be a valid JSON Schema.
          # This validation outcome of this keyword's subschema has no direct effect on the overall validation result. Rather, it controls which of the "then" or "else" keywords are evaluated.
          if_valid = schema_ptr['if'].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: true).valid?
          if if_valid
            if schema.key?('then')
              then_result = schema_ptr['then'].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
              validate.(then_result.valid?, 'instance did not validate against the schema defined by `then` value after validating against the schema defined by the `if` value', keyword, results: [then_result])
            end
          else
            if schema.key?('else')
              else_result = schema_ptr['else'].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
              validate.(else_result.valid?, 'instance did not validate against the schema defined by `else` value after not validating against the schema defined by the `if` value', keyword, results: [else_result])
            end
          end
        end

        # 9.2.2.4. dependentSchemas
        if schema.key?('dependentSchemas')
          keyword = 'dependentSchemas'
          value = schema[keyword]
          # This keyword specifies subschemas that are evaluated if the instance is an object and contains a certain property.
          #
          # This keyword's value MUST be an object. Each value in the object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # If the object key is a property in the instance, the entire instance must validate against the subschema. Its use is dependent on the presence of the property.
            if instance.respond_to?(:to_hash)
              results = value.keys.map do |property_name|
                if instance.key?(property_name)
                  schema_ptr['dependentSchemas'][property_name].as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
                end
              end.compact
              validate.(results.all?(:valid?), 'instance object does not validate against all schemas corresponding to matched property names specified by the `dependentSchemas` value', keyword, results: results)
            end
          else
            schema_error.('`dependentSchemas` is not an object', keyword)
          end
        end

        # 9.3. Keywords for Applying Subschemas to Child Instances

        # 9.3.1. Keywords for Applying Subschemas to Arrays

        # 9.3.1.1. items
        if schema.key?('items')
          keyword = 'items'
          value = schema[keyword]
          # The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
          if value.respond_to?(:to_ary)
            # If "items" is an array of schemas, validation succeeds if each element of the instance validates against the schema at the same position, if any.
            if instance.respond_to?(:to_ary)
              results = instance.each_index.map do |idx|
                if idx < value.size
                  schema_ptr['items'][idx].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
                elsif schema.key?('additionalItems')
                  schema_ptr['additionalItems'].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
                else
                  JSI::SchemaValidation::VALID
                end
              end
              validate.(results.all?(&:valid?), 'instance array items did not all validate against corresponding `items` or `additionalItems` schema values', keyword, results: results)
            end
          else
            # If "items" is a schema, validation succeeds if all elements in the array successfully validate against that schema.
            if instance.respond_to?(:to_ary)
              results = instance.each_index.map do |idx|
                schema_ptr['items'].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
              end
              validate.(results.all?(&:valid?), 'instance array items did not all validate against the `items` schema value', keyword, results: results)
            end
          end
        end

        # 9.3.1.4. contains
        if schema.key?('contains')
          keyword = 'contains'
          value = schema[keyword]
          # An array instance is valid against "contains" if at least one of its elements is valid against the given schema. Note that when collecting annotations, the subschema MUST be applied to every array element even after the first match has been found. This is to ensure that all possible annotations are collected.
          if instance.respond_to?(:to_ary)
            results = instance.each_index.map do |idx|
              schema_ptr['contains'].as_schema_ptr.schema_validate(schema_document, instance_ptr[idx], instance_document, validate_only: validate_only)
            end
            validate.(results.any?(&:valid?), 'instance array does not contain any items valid against the `contains` schema value', keyword, results: results)
          end
        end

        # 9.3.2. Keywords for Applying Subschemas to Objects

        evaluated_property_names = Set.new

        # 9.3.2.1. properties
        if schema.key?('properties')
          keyword = 'properties'
          value = schema[keyword]
          # The value of "properties" MUST be an object. Each value of this object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # Validation succeeds if, for each name that appears in both the instance and as a name within this keyword's value, the child instance for that name successfully validates against the corresponding schema.
            if instance.respond_to?(:to_hash)
              results = instance.keys.map do |property_name|
                if value.key?(property_name)
                  evaluated_property_names << property_name
                  schema_ptr['properties'][property_name].as_schema_ptr.schema_validate(schema_document, instance_ptr[property_name], instance_document, validate_only: validate_only)
                end
              end.compact
              validate.(results.all?(&:valid?), 'instance object properties do not all validate against corresponding `properties` schema values', keyword, results: results)
            end
          else
            schema_error.('`properties` is not an object', keyword)
          end
        end

        # 9.3.2.2. patternProperties
        if schema.key?('patternProperties')
          keyword = 'patternProperties'
          value = schema[keyword]
          # The value of "patternProperties" MUST be an object. Each property name of this object SHOULD be a valid regular expression, according to the ECMA 262 regular expression dialect. Each property value of this object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # Validation succeeds if, for each instance name that matches any regular expressions that appear as a property name in this keyword's value, the child instance for that name successfully validates against each schema that corresponds to a matching regular expression.
            if instance.respond_to?(:to_hash)
              results = instance.keys.map do |property_name|
                value.keys.map do |value_property_pattern|
                  begin
                    # TODO ECMA 262
                    if value_property_pattern.respond_to?(:to_str) && property_name.respond_to?(:to_str) && Regexp.new(value_property_pattern).match(property_name)
                      evaluated_property_names << property_name
                      schema_ptr['patternProperties'][value_property_pattern].as_schema_ptr.schema_validate(schema_document, instance_ptr[property_name], instance_document, validate_only: validate_only)
                    end
                  rescue RegexpError
                    nil
                  end
                end.compact
              end.inject([], &:+)
              validate.(results.all?(&:valid?), 'instance object properties do not all validate against corresponding `patternProperties` schema values', keyword, results: results)
            end
          else
            schema_error.('`patternProperties` is not an object', keyword)
          end
        end

        # 9.3.2.3. additionalProperties
        if schema.key?('additionalProperties')
          keyword = 'additionalProperties'
          value = schema[keyword]
          # The value of "additionalProperties" MUST be a valid JSON Schema.
          if instance.respond_to?(:to_hash)
            results = instance.keys.map do |property_name|
              if !evaluated_property_names.include?(property_name)
                schema_ptr['additionalProperties'].as_schema_ptr.schema_validate(schema_document, instance_ptr[property_name], instance_document, validate_only: validate_only)
              end
            end.compact
            validate.(results.all?(&:valid?), 'additional instance object properties do not all validate against `additionalProperties` schema value', keyword, results: results)
          end
        end

        # 9.3.2.5. propertyNames
        if schema.key?('propertyNames')
          keyword = 'propertyNames'
          value = schema[keyword]
          # The value of "propertyNames" MUST be a valid JSON Schema.
          # If the instance is an object, this keyword validates if every property name in the instance validates against the provided schema. Note the property name that the schema is testing will always be a string.
          if instance.respond_to?(:to_hash)
            results = instance.keys.map do |property_name|
              schema_ptr['propertyNames'].as_schema_ptr.schema_validate(schema_document, JSI::JSON::Pointer[], property_name, validate_only: validate_only)
            end
            validate.(results.all?(&:valid?), 'instance object property names do not all validate against `propertyNames` schema value', keyword, results: results)
          end
        end

        if schema.key?('$ref')
          keyword = '$ref'
          value = schema[keyword]

          schema_ptr.deref(schema_document) do |deref_ptr|
            ref_result = deref_ptr.as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
            validate.(ref_result.valid?, 'instance is not valid against the schema pointed to by the `$ref` value', keyword, results: [ref_result])
          end
        end

        if schema.key?('$recursiveRef')
          keyword = '$recursiveRef'
          value = schema[keyword]

          schema_ptr.deref(schema_document) do |deref_ptr|
            ref_result = deref_ptr.as_schema_ptr.schema_validate(schema_document, instance_ptr, instance_document, validate_only: validate_only)
            validate.(ref_result.valid?, 'instance is not valid against the schema pointed to by the `$recursiveRef` value', keyword, results: [ref_result])
          end
        end
      else
        schema_error.('schema is neither a boolean nor an object')
      end
      result.freeze
    end
  end
end
