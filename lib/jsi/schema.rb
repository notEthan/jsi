# frozen_string_literal: true

module JSI
  # JSI::Schema represents a JSON Schema. initialized from a Hash-like schema
  # object, JSI::Schema is a relatively simple class to abstract useful methods
  # applied to a JSON Schema.
  module Schema
    class Error < StandardError
    end

    # an exception raised when a thing is expected to be a JSI::Schema, but is not
    class NotASchemaError < Error
    end

    #
    class UndefinedIdFragment < Error
    end

    class ReferenceError < Error
    end

    autoload :Draft04, 'jsi/schema/draft04'
    autoload :Draft06, 'jsi/schema/draft06'
    autoload :Draft07, 'jsi/schema/draft07'
    autoload :Draft201909, 'jsi/schema/draft201909'

    module BigMoneyId
      def id
        keyword = '$id'
        if schema_content.respond_to?(:to_hash) && schema_content[keyword].respond_to?(:to_str)
          schema_content[keyword]
        else
          nil
        end
      end
    end

    module Id
      def id
        keyword = 'id'
        if schema_content.respond_to?(:to_hash) && schema_content[keyword].respond_to?(:to_str)
          schema_content[keyword]
        else
          nil
        end
      end
    end

    module BigMoneyAnchor
      def anchor
        keyword = '$anchor'
        # TODO warn (error?) unless value =~ /\A[A-Za-z][A-Za-z0-9\-_:.]*\z/
        if schema_content.respond_to?(:to_hash) && schema_content[keyword].respond_to?(:to_str)
          schema_content[keyword]
        else
          nil
        end
      end
    end

    module BigMoneyDefs
      def defs
        keyword = '$defs'
        if schema_content.respond_to?(:to_hash)
          schema_content[keyword]
        else
          nil
        end
      end
    end

    module Definitions
      def defs
        keyword = 'definitions'
        if schema_content.respond_to?(:to_hash)
          schema_content[keyword]
        else
          nil
        end
      end
    end

    class << self
      # @return [JSI::Schema] the default metaschema
      def default_metaschema
        JSI::JSONSchemaOrgDraft201909.schema
      end

      # @return [Array<JSI::Schema>] supported metaschemas
      def supported_metaschemas
        [
          JSI::JSONSchemaOrgDraft04.schema,
          JSI::JSONSchemaOrgDraft06.schema,
          JSI::JSONSchemaOrgDraft07.schema,
          JSI::JSONSchemaOrgDraft201909.schema,
        ]
      end

      # instantiates a given schema object as a JSI::Schema.
      #
      # schemas are instantiated according to their '$schema' property if specified. otherwise their schema
      # will be the {JSI::Schema.default_metaschema}.
      #
      # if the given schema_object is a JSI::Base but not a JSI::Schema, an error will be raised.
      #
      # @param schema_object [#to_hash, Boolean, JSI::Schema] an object to be instantiated as a schema.
      #   if it's already a schema, it is returned as-is.
      # @return [JSI::Schema] a JSI::Schema representing the given schema_object
      def from_object(schema_object, schema_id: nil)
        if schema_object.is_a?(Schema)
          schema_object
        elsif schema_object.is_a?(JSI::Base)
          raise(NotASchemaError, "the given schema_object is a JSI::Base, but is not a JSI::Schema: #{schema_object.pretty_inspect.chomp}")
        elsif schema_object.respond_to?(:to_hash)
          schema_object = JSI.deep_stringify_symbol_keys(schema_object)
          if schema_object.key?('$schema') && schema_object['$schema'].respond_to?(:to_str)
            if schema_object['$schema'] == schema_object['$id'] || schema_object['$schema'] == schema_object['id']
              MetaschemaNode.new(schema_object).tap { |schema| schema.jsi_register_schema(schema_id: schema_id) }
            else
              metaschema = supported_metaschemas.detect { |ms| schema_object['$schema'] == ms['$id'] || schema_object['$schema'] == ms['id'] }
              unless metaschema
                raise(NotImplementedError, "metaschema not supported: #{schema_object['$schema']}")
              end
              metaschema.new_jsi(schema_object).tap { |s| s.jsi_register_schema(schema_id: schema_id) }
            end
          else
            default_metaschema.new_jsi(schema_object).tap { |s| s.jsi_register_schema(schema_id: schema_id) }
          end
        elsif [true, false].include?(schema_object)
          default_metaschema.new_jsi(schema_object)
        else
          raise(TypeError, "cannot instantiate Schema from: #{schema_object.pretty_inspect.chomp}")
        end
      end

      alias_method :new, :from_object
    end

    def schema_content
return @schema_content if instance_variable_defined?(:@schema_content)
return @schema_content = jsi_node_content
    end

    def base_uri
      jsi_schema_base_uri
    end

    # @return [Addressable::URI, nil] the canonical URI for this schema
    def uri
      jsi_schema_uri
    end

    # @return [Addressable::URI, nil] URIs for this schema
    def uris
      jsi_subschema_resource_ancestors.map(&:uri).compact
    end

    # @return [#to_str, nil] the id of the schema - the value of the 'id' or '$id' schema keyword
    def id
      raise(NotImplementedError, "schema implementation must define #id")
    end

    # @return [String, nil] an absolute id for the schema, with a json pointer fragment. nil if
    #   no parent of this schema defines an id.
    def schema_id
      schema_ids.first
    end

    def schema_ids
      jsi_memoize(:schema_ids) do
        parent_schemas = jsi_parent_nodes(include_self: true).select { |node| node.is_a?(Schema) && node.id }

        schema_ids = parent_schemas.map do |parent_schema|
          parent_auri = Addressable::URI.parse(parent_schema.id)

          relative_ptr = self.jsi_ptr.ptr_relative_to(parent_schema.jsi_ptr)

          if parent_auri.fragment
            # this is not valid (unless the fragment is empty).
            # per the spec: "$id" MUST NOT contain a non-empty fragment, and SHOULD NOT contain an empty fragment.
            # we could (should?) throw an error, but for the moment I'll just add onto the existing $id fragment.
            parent_ptr = JSI::JSON::Pointer.from_fragment(parent_auri.fragment)
            relative_ptr = parent_ptr + relative_ptr
            parent_auri.fragment = nil
          end

          parent_auri.merge(fragment: relative_ptr.fragment).to_s
        end.compact
        schema_ids
      end
    end

    # @return [Module] a module representing this schema. see {JSI::SchemaClasses.module_for_schema}.
    def jsi_schema_module
      JSI::SchemaClasses.module_for_schema(self, schema_module_include: jsi_schema_instance_modules, schema_module_extend: jsi_schema_module_modules)
    end

    # @return [Class < JSI::Base] a JSI class for this one schema
    def jsi_schema_class
      JSI.class_for_schemas([self])
    end

    # instantiates the given other_instance as a JSI::Base class for schemas matched from this schema to the
    # other_instance.
    #
    # any parameters are passed to JSI::Base#initialize, but none are normally used.
    #
    # side effects:
    # - if the instantiated JSI is a {JSI::Schema}, it is registered with `JSI.schema_registry` (a {JSI::SchemaRegistry})
    #
    # @return [JSI::Base] a JSI whose instance is the given instance and whose schemas are matched from this
    #   schema.
    def new_jsi(other_instance, **a, &b)
      JSI.class_for_schemas(match_to_instance(other_instance)).new(other_instance, a, &b)
    end

    # @param schema_id [#to_str]
    def jsi_register_schema(schema_id: nil)
      JSI.schema_registry.register(self, schema_id: schema_id)
    end

    # @return [Boolean] does this schema itself describe a schema?
    def describes_schema?
      jsi_schema_instance_modules.any? { |m| m <= JSI::Schema }
    end

    # @return [Set<Module>] modules to apply to instances described by this schema
    def jsi_schema_instance_modules
      if instance_variable_defined?(:@jsi_schema_instance_modules)
        @jsi_schema_instance_modules
      else
        Set[]
      end
    end

    # @return [void]
    def jsi_schema_instance_modules=(jsi_schema_instance_modules)
      raise(TypeError) unless jsi_schema_instance_modules.is_a?(Set)
      raise(TypeError) unless jsi_schema_instance_modules.all? { |m| m.is_a?(Module) }
      @jsi_schema_instance_modules = jsi_schema_instance_modules
    end

    # @return [Set<Module>] modules to extend this schema's jsi_schema_module
    def jsi_schema_module_modules
      if instance_variable_defined?(:@jsi_schema_module_modules)
        @jsi_schema_module_modules
      else
        Set[]
      end
    end

    # @return [void]
    def jsi_schema_module_modules=(jsi_schema_module_modules)
      raise(TypeError) unless jsi_schema_module_modules.is_a?(Set)
      raise(TypeError) unless jsi_schema_module_modules.all? { |m| m.is_a?(Module) }
      @jsi_schema_module_modules = jsi_schema_module_modules
    end

    # returns a subschema of this Schema
    #
# @param *tokens [Array[Object]] tokens appended to our ptr indicating the location of the subschema
    # @return [JSI::Schema] the subschema at the location indicated by *tokens
    def subschema(*tokens)
      tokens_ptr = JSI::JSON::Pointer[*tokens]
      schema_resource_root = @jsi_subschema_resource_ancestors.last || jsi_root_node
      if schema_resource_root.is_a?(Metaschema)
#schema_class = JSI.class_for_schemas(self.jsi_schemas.select(&:describes_schema?))

# so if I have an items schema, which is a Schema and a properties/items
# then its subschema, say additionalProperties, would also be a properties/items
# write a test to validate self.jsi_schemas.select(&:describes_schema?)
byebug unless self.jsi_schemas.all?(&:describes_schema?)
schema_class = JSI.class_for_schemas(self.jsi_schemas)

        schema_class.new(Base.const_get(:NOINSTANCE),
          jsi_document: @jsi_document,
          jsi_ptr: @jsi_ptr + tokens_ptr,
          jsi_root_node: @jsi_root_node,
          jsi_schema_resource_ancestors: @jsi_subschema_resource_ancestors,
          jsi_schema_base_uri: @jsi_schema_uri || @jsi_schema_base_uri,
  #        jsi_schema_dynamic_scope: [],
        )
      else
        tokens_ptr.evaluate(self)
      end
    end

    def subschema_from_fragment(fragment)
      begin
        schema_from_resource_root(JSI::JSON::Pointer.from_fragment(fragment))
      rescue JSI::JSON::Pointer::PointerSyntaxError
        #if fragment =~ /\A[A-Za-z][A-Za-z0-9\-_:.]*\z/
        #  byebug
        #  schema
        #else
        #  return(@deref_schema = )
        #end
        subschema_for_anchor(fragment)
      end
    end

    # returns a schema in the same document as this one at the given pointer relative to the root
    # of the schema resource.
    #
    # the root of the schema resource is either a parent schema where a schema uri is defined by
    # the id keyword, or the root of the schema document.
    #
    # @param ptr [JSI::JSON::Pointer] pointer to a schema in our document
    # @return [JSI::BasicSchema] the schema in our document at the given pointer
    def schema_from_resource_root(ptr)
      #jsi_memoize(__method__, ptr) do |ptr|
        schema_resource_root = @jsi_subschema_resource_ancestors.last || jsi_root_node
        # TODO this seems possible to stack overflow in some case when schema_resource_root is a metaschema
#byebug if schema_resource_root.is_a?(Metaschema) && !ptr.root?
        result_schema = ptr.evaluate(schema_resource_root)

        if result_schema.is_a?(JSI::Schema)
          result_schema
        else
          # TODO warn; behavior is undefined and I hate this implementation
          # note that
          # - $id won't work
          # - weird behavior is possible when the schema location is described by other schemas (e.g. $ref: #/properties?)

          # TODO collect schemas for result_schema independent of evaluate
          schemas_for_result_schema = result_schema.is_a?(Base) ? result_schema.jsi_schemas : Set.new
          schemas_for_result_schema += self.jsi_schemas#.select(&:describes_schema?)
byebug unless self.jsi_schemas.all?(&:describes_schema?)
          schema_class = JSI.class_for_schemas(schemas_for_result_schema)

          schema_class.new(Base.const_get(:NOINSTANCE),
            jsi_document: @jsi_document,
            jsi_ptr: schema_resource_root.jsi_ptr + ptr,
            jsi_root_node: jsi_root_node,
            jsi_schema_resource_ancestors: schema_resource_root.jsi_subschema_resource_ancestors,
            jsi_schema_base_uri: schema_resource_root.jsi_schema_uri || schema_resource_root.jsi_schema_base_uri,
    #        jsi_schema_dynamic_scope: []
          )
        end
      #end
    end

    def subschemas
      jsi_memoize(:subschemas) do
        JSI::Util.ycomb do |rec|
          proc do |node|
            Set[].tap do |out|
              out << node if node.is_a?(JSI::Schema)

              if node.respond_to?(:to_hash)
                node.to_hash.values.each do |v|
                  out.merge(rec.call(v))
                end
              elsif node.respond_to?(:to_ary)
                node.to_ary.each do |e|
                  out.merge(rec.call(e))
                end
              end
            end
          end
        end.call(self)
      end
    end

    def subschemas_by_anchor
      return @subschemas_by_anchor if instance_variable_defined?(:@subschemas_by_anchor)
      @subschemas_by_anchor = {}.tap do |sba|
        subschemas.each do |subschema|
          if subschema.anchor
            sba[subschema.anchor] = subschema
          end
        end
      end
    end

    def subschema_for_anchor(anchor)
      if subschemas_by_anchor.key?(anchor)
        subschemas_by_anchor[anchor]
      else
byebug
subschemas_by_anchor
        raise(ReferenceError, "could not find anchor #{anchor.inspect} in schema (#{self.class.inspect}):\n#{schema_content.pretty_inspect.chomp}")
      end
    end

    # checks this schema for applicators ($ref, allOf, etc.) which should be applied to the given instance.
    # returns these as a Set of {JSI::Schema}s.
    # the returned set will contain this schema itself, unless this schema contains a $ref or a $recursiveRef
    # with no other keywords.
    #
    # @param instance [Object] the instance to check any applicators against
    # @param visited_refs [Enumerable<JSI::SchemaRef>]
    # @return [Set<JSI::Schema>] matched applicator schemas
    def match_to_instance(instance, visited_refs: [])
      Set.new.tap do |schemas|
        if schema_content.respond_to?(:to_hash)
          if schema_content['$ref'].respond_to?(:to_str)
            keyword = '$ref'
            ref = SchemaRef.new(self, keyword)

            if visited_refs.include?(ref)
# conditional
#schemas << self
            else
              schemas.merge(ref.deref_schema.match_to_instance(instance, visited_refs: visited_refs + [ref]))
            end
            recursive_ref = !self.jsi_schemas.any? { |s| s.described_object_property_names.include?('$recursiveRef') }
#            recursive_ref = !self.jsi_schemas.map(&:described_object_property_names).inject(Set[], &:|).include?('$recursiveRef')
          end
          if schema_content['$recursiveRef'].respond_to?(:to_str)
            keyword = '$recursiveRef'
            ref = SchemaRef.new(self, keyword)
            if visited_refs.include?(ref)
#wtf
#schemas << self
            else
              schemas.merge(ref.deref_schema.match_to_instance(instance, visited_refs: visited_refs + [ref]))
            end
            recursive_ref = true
          end
          unless recursive_ref
            schemas << self
          end
          if schema_content['allOf'].respond_to?(:to_ary)
            schema_content['allOf'].each_index do |i|
              schemas.merge(subschema('allOf', i).match_to_instance(instance, visited_refs: visited_refs))
            end
          end
          if schema_content['anyOf'].respond_to?(:to_ary)
            schema_content['anyOf'].each_index do |i|
              if subschema('anyOf', i).instance_valid?(instance)
                schemas.merge(subschema('anyOf', i).match_to_instance(instance, visited_refs: visited_refs))
              end
            end
          end
          if schema_content['oneOf'].respond_to?(:to_ary)
            one_i = schema_content['oneOf'].each_index.detect do |i|
              subschema('oneOf', i).instance_valid?(instance)
            end
            if one_i
              schemas.merge(subschema('oneOf', one_i).match_to_instance(instance, visited_refs: visited_refs))
            end
          end
          # TODO dependencies
        else
          schemas << self
        end
      end
    end

    # returns a set of subschemas of this schema for the given property name.
    #
    # @param property_name [String] the property name for which to find subschemas
# @param property_name [Object] the property name for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given property_name, using
    #   `properties`, `patternProperties`, and `additionalProperties`
    def subschemas_for_property_name(property_name)
      jsi_memoize(__method__, property_name) do |property_name|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            apply_additional = true
            if schema_content.key?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(property_name)
              apply_additional = false
              subschemas << subschema('properties', property_name)
            end
            if schema_content['patternProperties'].respond_to?(:to_hash)
              schema_content['patternProperties'].each_key do |pattern|
                if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  subschemas << subschema('patternProperties', pattern)
                end
              end
            end
            if apply_additional && schema_content.key?('additionalProperties')
              subschemas << subschema('additionalProperties')
            end
          end
        end
      end
    end

    # returns a set of subschemas of this schema for the given array index.
    #
    # @param idx [Integer] the array index for which to find subschemas
# @param idx [Object] the array index for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given array index, using
    #   `items` and `additionalItems`
    def subschemas_for_index(idx)
      jsi_memoize(__method__, idx) do |idx|
        Set.new.tap do |subschemas|
          if schema_content.respond_to?(:to_hash)
            if schema_content['items'].respond_to?(:to_ary)
              if schema_content['items'].each_index.to_a.include?(idx)
                subschemas << subschema('items', idx)
              elsif schema_content.key?('additionalItems')
                subschemas << subschema('additionalItems')
              end
            elsif schema_content.key?('items')
              subschemas << subschema('items')
            end
          end
        end
      end
    end

    # @return [Set] any object property names this schema indicates may be present on its instances.
    #   this includes any keys of this schema's "properties" object and any entries of this schema's
    #   array of "required" property keys.
    def described_object_property_names
      jsi_memoize(:described_object_property_names) do
        Set.new.tap do |property_names|
          if jsi_node_content.respond_to?(:to_hash) && jsi_node_content['properties'].respond_to?(:to_hash)
            property_names.merge(jsi_node_content['properties'].keys)
          end
          if jsi_node_content.respond_to?(:to_hash) && jsi_node_content['required'].respond_to?(:to_ary)
            property_names.merge(jsi_node_content['required'].to_ary)
          end
        end
      end
    end

    def validate_instance(instance)
      if instance.is_a?(JSI::PathedNode)
        instance_ptr = instance.jsi_ptr
        instance_document = instance.jsi_document
      else
        instance_ptr = JSI::JSON::Pointer[]
        instance_document = instance
      end
      internal_validate_instance(instance_ptr, instance_document)
    end

    # indicates whether the given instance validates this schema
    #
    # @param instance_ptr [JSI::JSON::Pointer] a pointer to the instance to validate against the schema, in the instance_document
    # @param instance_document [#to_hash, #to_ary, Object] document containing the instance instance_ptr pointer points to
    # @return [Boolean]
    def instance_valid?(instance)
      if instance.is_a?(JSI::PathedNode)
        instance = instance.jsi_node_content
      end
      internal_validate_instance(JSI::JSON::Pointer[], instance, validate_only: true).valid?
    end

    # validates the given instance against this schema
    #
    # @private
    # @param instance_ptr [JSI::JSON::Pointer] a pointer to the instance to validate against the schema, in the instance_document
    # @param instance_document [#to_hash, #to_ary, Object] document containing the instance instance_ptr pointer points to
    # @param validate_only [Boolean] whether to return a SchemaApplicationResult or a SchemaValidResult
    # @return [SchemaApplicationResult, SchemaValidResult]
    def internal_validate_instance(instance_ptr, instance_document, validate_only: false, visited_refs: [])
      instance = instance_ptr.evaluate(instance_document)

      if validate_only
        result = SchemaValidation::AnnotatedValidityResult.new
        result_annotate = Util::NOOP
        schema_warning = Util::NOOP
        schema_error = Util::NOOP
      else
        result = SchemaValidation::FullResult.new
        result_annotate = proc do |keyword, value|
          result.annotations << SchemaValidation::Annotation.new({
            keyword: keyword,
            value: value,
            instance_ptr: instance_ptr,
            instance_document: instance_document,
            schema: self,
          })
        end

        schema_issue = proc do |level, message, keyword = nil|
          result.schema_issues << SchemaValidation::SchemaIssue.new({
            level: level,
            message: message,
            keyword: keyword,
            schema: self,
          })
        end
        schema_error = proc do |message, keyword = nil|
          schema_issue.(:error, message, keyword)
        end
        schema_warning = proc do |message, keyword = nil|
          schema_issue.(:warning, message, keyword)
        end
      end

      result_validate = proc do |valid, message, keyword = nil, results: [], annotations: []|
        if valid
          results.select(&:valid?).each { |res| result.annotations.merge(res.annotations) }
          result.annotations.merge(annotations)

          unless validate_only
            results.each { |res| result.schema_issues.merge(res.schema_issues) }
          end
        else
          if validate_only
            return SchemaValidation::INVALID
          else
            results.each { |res| result.validation_errors.merge(res.validation_errors) }
            result.validation_errors << SchemaValidation::ValidationError.new({
              message: message,
              keyword: keyword,
              schema: self,
              instance_ptr: instance_ptr,
              instance_document: instance_document,
            })
          end
        end
      end

      subschema_validate = proc do |subschema, subinstance_ptr|
        subresult = subschema.internal_validate_instance(subinstance_ptr, instance_document, validate_only: validate_only)
        unless validate_only
          # subresult validation_errors do not necessarily go into our result (the caller handles that),
          # but schema_issues always do.
          result.schema_issues.merge(subresult.schema_issues)
        end
        subresult
      end

      if schema_content == true
        # (noop)
      elsif schema_content == false
        result_validate.(false, "false schema")
      elsif schema_content.respond_to?(:to_hash)
        if schema_content.key?('$ref')
          keyword = '$ref'
          value = schema_content[keyword]

          if value.respond_to?(:to_str)
            schema_ref = SchemaRef.new(self, keyword)

            if visited_refs.include?(schema_ref)
              schema_error.('self-referential schema structure', keyword)
            else
byebug unless schema_ref.deref_schema.is_a?(JSI::Schema)
              ref_result = schema_ref.deref_schema.internal_validate_instance(instance_ptr, instance_document, validate_only: validate_only, visited_refs: visited_refs + [schema_ref])
              result_validate.(
                ref_result.valid?,
                'instance is not valid against the schema pointed to by the `$ref` value',
                keyword,
                results: [ref_result],
              )
            end
          else
            schema_error.("`$ref` is not a string", keyword)
          end
        end

        if schema_content.key?('$recursiveRef')
          keyword = '$recursiveRef'
          value = schema_content[keyword]

          if value.respond_to?(:to_str)
            schema_ref = SchemaRef.new(self, keyword)

            if visited_refs.include?(schema_ref)
              schema_error.('self-referential schema structure', keyword)
            else
              ref_result = schema_ref.deref_schema.internal_validate_instance(instance_ptr, instance_document, validate_only: validate_only, visited_refs: visited_refs + [schema_ref])
              result_validate.(
                ref_result.valid?,
                'instance is not valid against the schema pointed to by the `$recursiveRef` value',
                keyword,
                results: [ref_result],
              )
            end
          else
            schema_error.("`$recursiveRef` is not a string", keyword)
          end
        end

        # 6.1. Validation Keywords for Any Instance Type
        if schema_content.key?('type') # 6.1.1. type
          keyword = 'type'
          value = schema_content[keyword]
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
                  schema_error.("`type` is not one of: null, boolean, object, array, string, number, or integer", keyword)
                end
              else
                schema_error.("`type` is not a string at index #{i}", keyword)
              end
            end
            result_validate.(matched_type, 'instance type does not match `type` value', keyword)
          else
            schema_error.('`type` is not a string or array', keyword)
          end
        end

        # 6.1.2. enum
        if schema_content.key?('enum')
          keyword = 'enum'
          value = schema_content[keyword]
          # The value of this keyword MUST be an array. This array SHOULD have at least one element.
          # Elements in the array SHOULD be unique.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if its value is equal to one of the
            # elements in this keyword's array value.
            result_validate.(value.include?(instance), 'instance is not equal to any `enum` value', keyword)
          else
            schema_error.('`enum` is not an array', keyword)
          end
        end

        # 6.1.3. const
        if schema_content.key?('const')
          keyword = 'const'
          value = schema_content[keyword]
          # The value of this keyword MAY be of any type, including null.
          # An instance validates successfully against this keyword if its value is equal to the value of
          # the keyword.
          result_validate.(instance == value, 'instance is not equal to `const` value', keyword)
        end

        # 6.2. Validation Keywords for Numeric Instances (number and integer)

        # 6.2.1. multipleOf
        if schema_content.key?('multipleOf')
          keyword = 'multipleOf'
          value = schema_content[keyword]
          # The value of "multipleOf" MUST be a number, strictly greater than 0.
          if value.is_a?(Numeric) && value > 0
            # A numeric instance is valid only if division by this keyword's value results in an integer.
            if instance.is_a?(Numeric)
              if instance.is_a?(Integer) && value.is_a?(Integer)
                result_validate.(instance % value == 0, 'instance is not a multiple of `multipleOf` value', keyword)
              else
                result_validate.((instance / value) % 1.0 == 0.0, 'instance is not a multiple of `multipleOf` value', keyword)
              end
            end
          else
            schema_error.('`multipleOf` is not a number greater than 0', keyword)
          end
        end

        # 6.2.2. maximum
        if schema_content.key?('maximum')
          keyword = 'maximum'
          value = schema_content[keyword]
          # The value of "maximum" MUST be a number, representing an inclusive upper limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then this keyword validates only if the instance is less than
            # or exactly equal to "maximum".
            if instance.is_a?(Numeric)
              result_validate.(instance <= value, 'instance is not less than or equal to `maximum` value', keyword)
            end
          else
            schema_error.('`maximum` is not a number', keyword)
          end
        end

        # 6.2.3. exclusiveMaximum
        if schema_content.key?('exclusiveMaximum')
          keyword = 'exclusiveMaximum'
          value = schema_content[keyword]
          # The value of "exclusiveMaximum" MUST be number, representing an exclusive upper limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then the instance is valid only if it has a value strictly less than (not equal to) "exclusiveMaximum".
            if instance.is_a?(Numeric)
              result_validate.(instance < value, 'instance is not less than `exclusiveMaximum` value', keyword)
            end
          else
            schema_error.('`exclusiveMaximum` is not a number', keyword)
          end
        end

        # 6.2.4. minimum
        if schema_content.key?('minimum')
          keyword = 'minimum'
          value = schema_content[keyword]
          # The value of "minimum" MUST be a number, representing an inclusive lower limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then this keyword validates only if the instance is greater than or exactly equal to "minimum".
            if instance.is_a?(Numeric)
              result_validate.(instance >= value, 'instance is not greater than or equal to `minimum` value', keyword)
            end
          else
            schema_error.('`minimum` is not a number', keyword)
          end
        end

        # 6.2.5. exclusiveMinimum
        if schema_content.key?('exclusiveMinimum')
          keyword = 'exclusiveMinimum'
          value = schema_content[keyword]
          # The value of "exclusiveMinimum" MUST be number, representing an exclusive lower limit for a numeric instance.
          if value.is_a?(Numeric)
            # If the instance is a number, then the instance is valid only if it has a value strictly greater than (not equal to) "exclusiveMinimum".
            if instance.is_a?(Numeric)
              result_validate.(instance > value, 'instance is not greater than `exclusiveMinimum` value', keyword)
            end
          else
            schema_error.('`exclusiveMinimum` is not a number', keyword)
          end
        end

        # 6.3. Validation Keywords for Strings

        # 6.3.1. maxLength
        if schema_content.key?('maxLength')
          keyword = 'maxLength'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_str)
              # A string instance is valid against this keyword if its length is less than, or equal to, the value of this keyword.
              result_validate.(instance.to_str.length <= value, 'instance string length is not less than or equal to `maxLength` value', keyword)
            end
          else
            schema_error.('`maxLength` is not a non-negative integer', keyword)
          end
        end

        # 6.3.2. minLength
        if schema_content.key?('minLength')
          keyword = 'minLength'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_str)
              # A string instance is valid against this keyword if its length is greater than, or equal to, the value of this keyword.
              result_validate.(instance.to_str.length >= value, 'instance string length is not greater than or equal to `minLength` value', keyword)
            end
          else
            schema_error.('`minLength` is not a non-negative integer', keyword)
          end
        end

        # 6.3.3. pattern
        if schema_content.key?('pattern')
          keyword = 'pattern'
          value = schema_content[keyword]
          # The value of this keyword MUST be a string.
          if value.respond_to?(:to_str)
            if instance.respond_to?(:to_str)
              begin
                # This string SHOULD be a valid regular expression, according to the ECMA 262 regular expression dialect.
                # TODO
                regexp = Regexp.new(value)
                # A string instance is considered valid if the regular expression matches the instance successfully. Recall: regular expressions are not implicitly anchored.
                result_validate.(regexp.match(instance), 'instance string does not match `pattern` regular expression value', keyword)
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
        if schema_content.key?('maxItems')
          keyword = 'maxItems'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "maxItems" if its size is less than, or equal to, the value of this keyword.
              result_validate.(instance.to_ary.size <= value, 'instance array size is greater than `maxItems` value', keyword)
            end
          else
            schema_error.('`maxItems` is not a non-negative integer', keyword)
          end
        end

        # 6.4.2. minItems
        if schema_content.key?('minItems')
          keyword = 'minItems'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_ary)
              # An array instance is valid against "minItems" if its size is greater than, or equal to, the value of this keyword.
              result_validate.(instance.to_ary.size >= value, 'instance array size is less than `minItems` value', keyword)
            end
          else
            schema_error.('`minItems` is not a non-negative integer', keyword)
          end
        end

        # 6.4.3. uniqueItems
        if schema_content.key?('uniqueItems')
          keyword = 'uniqueItems'
          value = schema_content[keyword]
          # The value of this keyword MUST be a boolean.
          if value == false
            # If this keyword has boolean value false, the instance validates successfully.
            # (noop)
          elsif value == true
            if instance.respond_to?(:to_ary)
              # If it has boolean value true, the instance validates successfully if all of its elements are unique.
              result_validate.(instance.uniq.size == instance.size, "instance array items' uniqueness does not match `uniqueItems` value", keyword)
            end
          else
            schema_error.('`uniqueItems` is not a boolean', keyword)
          end
        end

        # 6.4.4. maxContains
        if schema_content.key?('maxContains')
          keyword = 'maxContains'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if schema_content.key?('contains')
              if instance.respond_to?(:to_ary)
                # An array instance is valid against "maxContains" if the number of elements that are valid
                # against the schema for "contains" is less than, or equal to, the value of this keyword.
                results = instance.each_index.map do |i|
                  subschema_validate.(subschema('contains'), instance_ptr[i])
                end
  # TODO better info on what items passed/failed validation
  x              result_validate.(
                  results.select(&:valid?).size <= value,
                  'instance array contains more items valid against the `contains` schema than the `maxContains` value',
                  keyword,
                  results: results,
                )
                validate.(results.select(&:valid?).size <= value, 'instance array contains more items valid against the `contains` schema than the `maxContains` value', keyword)
              end
            else
              schema_warning.('`maxContains` has no effect without adjacent `contains` keyword', keyword)
            end
          else
            schema_error.('`maxContains` is not a non-negative integer', keyword)
          end
        end

        # 6.4.5. minContains
        if schema_content.key?('minContains')
          keyword = 'minContains'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
if value < 1
  schema_warning.('`minContains` value of 0 is specified without adjacent `contains` keyword', keyword)
end
            if schema_content.key?('contains')
              if instance.respond_to?(:to_ary)
                # An array instance is valid against "minContains" if the number of elements that are valid
                # against the schema for "contains" is greater than, or equal to, the value of this keyword.
# TODO have this be a result of 'contains' annotations rather than redundantly validating
                results = instance.each_index.map do |i|
                  subschema_validate.(subschema('contains'), instance_ptr[i])
                end
                result_validate.(
                  results.select(&:valid?).size >= value,
                  'instance array contains fewer items valid against the `contains` schema than the `minContains` value',
                  keyword,
                  results: results,
                )
              end
            else
              schema_warning.('`minContains` has no effect without adjacent `contains` keyword', keyword)
            end
          else
            schema_error.('`minContains` is not a non-negative integer', keyword)
          end
        end

        # 6.5. Validation Keywords for Objects

        # 6.5.1. maxProperties
        if schema_content.key?('maxProperties')
          keyword = 'maxProperties'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_hash)
              # An object instance is valid against "maxProperties" if its number of properties is less than, or equal to, the value of this keyword.
              result_validate.(instance.size <= value, 'instance object contains more properties than the `maxProperties` value', keyword)
            end
          else
            schema_error.('`maxProperties` is not a non-negative integer', keyword)
          end
        end

        # 6.5.2. minProperties
        if schema_content.key?('minProperties')
          keyword = 'minProperties'
          value = schema_content[keyword]
          # The value of this keyword MUST be a non-negative integer.
          if value.is_a?(Integer) && value >= 0
            if instance.respond_to?(:to_hash)
              # An object instance is valid against "minProperties" if its number of properties is greater than, or equal to, the value of this keyword.
              result_validate.(instance.size >= value, 'instance object contains fewer properties than the `minProperties` value', keyword)
            end
          else
            schema_error.('`minProperties` is not a non-negative integer', keyword)
          end
        end

        # 6.5.3. required
        if schema_content.key?('required')
          keyword = 'required'
          value = schema_content[keyword]
          # The value of this keyword MUST be an array. Elements of this array, if any, MUST be strings, and MUST be unique.
          if value.respond_to?(:to_ary)
            if instance.respond_to?(:to_hash)
              # An object instance is valid against this keyword if every item in the array is the name of a property in the instance.
              missing_required = value.reject { |property_name| instance.key?(property_name) }
              # TODO include missing required property names in the validation error
              result_validate.(missing_required.empty?, 'instance object does not contain all property names specified by the `required` value', keyword)
            end
          else
            schema_error.('`required` is not an array', keyword)
          end
        end

        # 6.5.4. dependentRequired
        if schema_content.key?('dependentRequired')
          keyword = 'dependentRequired'
          value = schema_content[keyword]
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
              result_validate.(missing_dependent_required.empty?, 'instance object does not contain all dependent required property names specified by the `dependentRequired` value', keyword)
            end
          else
            schema_error.('`dependentRequired` is not an object whose properties are arrays', keyword)
          end
        end

        # 7. A Vocabulary for Semantic Content With "format"
        if schema_content.key?('format')
          keyword = 'format'
          value = schema_content[keyword]

          result_annotate.(keyword, value)
        end

        # A Vocabulary for Basic Meta-Data Annotations https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9

        # string annotations

        # "title" and "description" https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.1
        %w(title description).each do |keyword|
          if schema_content.key?(keyword)
            value = schema_content[keyword]

            if value.respond_to?(:to_str)
              result_annotate.(keyword, value)
            else
              schema_error.("`#{keyword}` is not a string", keyword)
            end
          end
        end

        # boolean annotations

        # "deprecated" https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.3
        # "readOnly" and "writeOnly" https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.4
        %w(deprecated readOnly writeOnly).each do |keyword|
          if schema_content.key?(keyword)
            value = schema_content[keyword]

            if [true, false].include?(value)
              result_annotate.(keyword, value)
            else
              schema_error.("`#{keyword}` is not a boolean", keyword)
            end
          end
        end

        # "default" https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.2
        keyword = 'default'
        if schema_content.key?(keyword)
          value = schema_content[keyword]

          result_annotate.(keyword, value)
        end

        # 9.5. "examples" https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.5
        keyword = 'examples'
        if schema_content.key?(keyword)
          value = schema_content[keyword]

          if value.respond_to?(:to_ary)
            result_annotate.(keyword, value)
          else
            schema_error.("`#{keyword}` is not an array", keyword)
          end
        end

        # json-schema-core 9.2.  Keywords for Applying Subschemas in Place

        # json-schema-core 9.2.1.  Keywords for Applying Subschemas With Boolean Logic

        # json-schema-core 9.2.1.1. allOf
        if schema_content.key?('allOf')
          keyword = 'allOf'
          value = schema_content[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against all schemas defined by this keyword's value.
            allOf_results = value.each_index.map do |i|
              subschema_validate.(subschema('allOf', i), instance_ptr)
            end
            result_validate.(
              allOf_results.all?(&:valid?),
              'instance did not validate against all schemas defined by `allOf` value',
              keyword,
              results: allOf_results,
            )
          else
            schema_error.('`allOf` is not an array', keyword)
          end
        end

        # json-schema-core 9.2.1.2. anyOf
        if schema_content.key?('anyOf')
          keyword = 'anyOf'
          value = schema_content[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against at least one schema defined by this keyword's value. Note that when annotations are being collected, all subschemas MUST be examined so that annotations are collected from each subschema that validates successfully.
            anyOf_results = value.each_index.map do |i|
              subschema_validate.(subschema('anyOf', i), instance_ptr)
            end
            result_validate.(
              anyOf_results.any?(&:valid?),
              'instance did not validate against any schemas defined by `anyOf` value',
              keyword,
              results: anyOf_results,
            )
          else
            schema_error.('`anyOf` is not an array', keyword)
          end
        end

        # json-schema-core 9.2.1.3. oneOf
        if schema_content.key?('oneOf')
          keyword = 'oneOf'
          value = schema_content[keyword]
          # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
          if value.respond_to?(:to_ary)
            # An instance validates successfully against this keyword if it validates successfully against exactly one schema defined by this keyword's value.
            oneOf_results = value.each_index.map do |i|
              subschema_validate.(subschema('oneOf', i), instance_ptr)
            end
            if oneOf_results.none?(&:valid?)
              result_validate.(
                false,
                'instance did not validate against any schemas defined by `oneOf` value',
                keyword,
                results: oneOf_results,
              )
            else
              # TODO better info on what schemas passed/failed validation
              result_validate.(
                oneOf_results.select(&:valid?).size == 1,
                'instance validated against multiple schemas defined by `oneOf` value',
                keyword,
                results: oneOf_results,
              )
            end
          else
            schema_error.('`oneOf` is not an array', keyword)
          end
        end

        # json-schema-core 9.2.1.4. not
        if schema_content.key?('not')
          keyword = 'not'
          value = schema_content[keyword]
          # This keyword's value MUST be a valid JSON Schema.
          # An instance is valid against this keyword if it fails to validate successfully against the schema defined by this keyword.
          not_valid = subschema_validate.(subschema('not'), instance_ptr).valid?
          result_validate.(!not_valid, 'instance validated against the schema defined by `not` value', keyword)
        end

        # json-schema-core 9.2.2. Keywords for Applying Subschemas Conditionally

        # json-schema-core 9.2.2.1. if
        keyword = 'if'
        if schema_content.key?(keyword)
          value = schema_content[keyword]

          # This keyword's value MUST be a valid JSON Schema.
          # This validation outcome of this keyword's subschema has no direct effect on the overall validation result. Rather, it controls which of the "then" or "else" keywords are evaluated.
          if_result = subschema_validate.(subschema('if'), instance_ptr)

          unless validate_only
            result.schema_issues.merge(if_result.schema_issues)
          end
          if if_result.valid?
            result.annotations.merge(if_result.annotations)
          end

          if if_result.valid?
            if schema_content.key?('then')
              then_result = subschema_validate.(subschema('then'), instance_ptr)
              result_validate.(
                then_result.valid?,
                'instance did not validate against the schema defined by `then` value after validating against the schema defined by the `if` value',
                keyword,
                results: [then_result],
              )
            end
          else
            if schema_content.key?('else')
              else_result = subschema_validate.(subschema('else'), instance_ptr)
              result_validate.(
                else_result.valid?,
                'instance did not validate against the schema defined by `else` value after not validating against the schema defined by the `if` value',
                keyword,
                results: [else_result],
              )
            end
          end
        else
          if schema_content.key?('then')
            schema_warning.('`then` has no effect without adjacent `if` keyword', keyword)
          end
          if schema_content.key?('else')
            schema_warning.('`else` has no effect without adjacent `if` keyword', keyword)
          end
        end

        # json-schema-core 9.2.2.4. dependentSchemas
        if schema_content.key?('dependentSchemas')
          keyword = 'dependentSchemas'
          value = schema_content[keyword]
          # This keyword specifies subschemas that are evaluated if the instance is an object and contains a certain property.
          #
          # This keyword's value MUST be an object. Each value in the object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # If the object key is a property in the instance, the entire instance must validate against the subschema. Its use is dependent on the presence of the property.
            if instance.respond_to?(:to_hash)
              results = value.keys.map do |property_name|
                if instance.key?(property_name)
                  subschema_validate.(subschema('dependentSchemas', property_name), instance_ptr)
                end
              end.compact
              result_validate.(
                results.all?(&:valid?),
                'instance object does not validate against all schemas corresponding to matched property names specified by the `dependentSchemas` value',
                keyword,
                results: results,
              )
            end
          else
            schema_error.('`dependentSchemas` is not an object', keyword)
          end
        end

        # json-schema-core 9.3. Keywords for Applying Subschemas to Child Instances

        # json-schema-core 9.3.1. Keywords for Applying Subschemas to Arrays

# evaluated_indices = Set.new

        # json-schema-core 9.3.1.1. items
        if schema_content.key?('items')
          keyword = 'items'
          value = schema_content[keyword]
          # The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
          if value.respond_to?(:to_ary)
            # If "items" is an array of schemas, validation succeeds if each element of the instance validates against the schema at the same position, if any.
            if instance.respond_to?(:to_ary)
              items_annotation = nil
              additionalItems_annotion = nil
              results = {}
              instance.each_index do |i|
                if i < value.size
                  items_annotation = i
                  results[i] = subschema_validate.(subschema('items', i), instance_ptr[i])
                elsif schema_content.key?('additionalItems')
                  additionalItems_annotion = true
                  results[i] = subschema_validate.(subschema('additionalItems'), instance_ptr[i])
                end
              end
              annotations = Set[]
              if items_annotation
                # This keyword produces an annotation value which is the largest index to which this keyword
                # applied a subschema.
                annotations << SchemaValidation::Annotation.new(
                  keyword: 'items',
                  value: items_annotation,
                  instance_ptr: instance_ptr,
                  instance_document: instance_document,
                  schema: self,
                )
              end
              if additionalItems_annotion
                # If the "additionalItems" subschema is applied to any positions within the instance array,
                # it produces an annotation result of boolean true, analogous to the single schema behavior
                # of "items".
                annotations << SchemaValidation::Annotation.new(
                  keyword: 'additionalItems',
                  value: additionalItems_annotion,
                  instance_ptr: instance_ptr,
                  instance_document: instance_document,
                  schema: self,
                )
              end
              result_validate.(
                results.values.all?(&:valid?),
                'instance array items did not all validate against corresponding `items` or `additionalItems` schema values',
                keyword,
                results: results.values,
                annotations: annotations,
              )
            end
          else
            # If "items" is a schema, validation succeeds if all elements in the array successfully validate against that schema.
            if instance.respond_to?(:to_ary)
              results = instance.each_index.map do |i|
                subschema_validate.(subschema('items'), instance_ptr[i])
              end
              result_validate.(
                results.all?(&:valid?),
                'instance array items did not all validate against the `items` schema value',
                keyword,
                results: results,
                # This keyword produces an annotation value ... The value MAY be a boolean true if a subschema
                # was applied to every index of the instance, such as when "items" is a schema.
                annotations: [
                  SchemaValidation::Annotation.new(
                    keyword: keyword,
                    value: true,
                    instance_ptr: instance_ptr,
                    instance_document: instance_document,
                    schema: self,
                  )
                ],
              )
            end
          end
        else
          if schema_content.key?('additionalItems')
            schema_warning.('`additionalItems` has no effect without adjacent `items` keyword', keyword)
          end
        end

        # json-schema-core 9.3.1.4. contains
        if schema_content.key?('contains')
          keyword = 'contains'
          value = schema_content[keyword]
          # An array instance is valid against "contains" if at least one of its elements is valid against the given schema. Note that when collecting annotations, the subschema MUST be applied to every array element even after the first match has been found. This is to ensure that all possible annotations are collected.
          if instance.respond_to?(:to_ary)
            results = {}
            instance.each_index do |i|
              results[i] = subschema_validate.(subschema('contains'), instance_ptr[i])
            end
            result_validate.(
              results.values.any?(&:valid?),
              'instance array does not contain any items valid against the `contains` schema value',
              keyword,
              results: results.values,
#              annotations: [
#                SchemaValidation::Annotation.new(
#                  keyword: keyword,
#                  value: results.each_index.select do |i|
#                    results[i].valid?
#                  end,
#                  instance_ptr: instance_ptr,
#                  instance_document: instance_document,
#                  schema: self,
#                )
#              ],
            )
          end
        end

        # json-schema-core 9.3.2. Keywords for Applying Subschemas to Objects

        evaluated_property_names = Set.new

        # json-schema-core 9.3.2.1. properties
        if schema_content.key?('properties')
          keyword = 'properties'
          value = schema_content[keyword]
          # The value of "properties" MUST be an object. Each value of this object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # Validation succeeds if, for each name that appears in both the instance and as a name within this keyword's value, the child instance for that name successfully validates against the corresponding schema.
            if instance.respond_to?(:to_hash)
              results = {}
              instance.keys.each do |property_name|
                if value.key?(property_name)
                  evaluated_property_names << property_name
                  results[property_name] = subschema_validate.(subschema('properties', property_name), instance_ptr[property_name])
                end
              end
              result_validate.(
                results.values.all?(&:valid?),
                'instance object properties do not all validate against corresponding `properties` schema values',
                keyword,
                results: results.values,
                annotations: [
                  SchemaValidation::Annotation.new(
                    keyword: keyword,
                    value: results.keys.select do |property_name|
                      results[property_name].valid?
                    end,
                    instance_ptr: instance_ptr,
                    instance_document: instance_document,
                    schema: self,
                  )
                ],
              )
            end
          else
            schema_error.('`properties` is not an object', keyword)
          end
        end

        # json-schema-core 9.3.2.2. patternProperties
        if schema_content.key?('patternProperties')
          keyword = 'patternProperties'
          value = schema_content[keyword]
          # The value of "patternProperties" MUST be an object. Each property name of this object SHOULD be a valid regular expression, according to the ECMA 262 regular expression dialect. Each property value of this object MUST be a valid JSON Schema.
          if value.respond_to?(:to_hash)
            # Validation succeeds if, for each instance name that matches any regular expressions that appear as a property name in this keyword's value, the child instance for that name successfully validates against each schema that corresponds to a matching regular expression.
            if instance.respond_to?(:to_hash)
              results = {}
              instance.keys.each do |property_name|
                value.keys.each do |value_property_pattern|
                  begin
                    # TODO ECMA 262
                    if value_property_pattern.respond_to?(:to_str) && property_name.respond_to?(:to_str) && Regexp.new(value_property_pattern).match(property_name)
                      evaluated_property_names << property_name
                      results[property_name] = subschema_validate.(subschema('patternProperties', value_property_pattern), instance_ptr[property_name])
                    end
                  rescue RegexpError
                    nil
                  end
                end
              end
              result_validate.(
                results.values.all?(&:valid?),
                'instance object properties do not all validate against corresponding `patternProperties` schema values',
                keyword,
                results: results.values,
                annotations: [
                  SchemaValidation::Annotation.new(
                    keyword: keyword,
                    value: results.keys.select do |property_name|
                      results[property_name].valid?
                    end,
                    instance_ptr: instance_ptr,
                    instance_document: instance_document,
                    schema: self,
                  )
                ],
              )
            end
          else
            schema_error.('`patternProperties` is not an object', keyword)
          end
        end

        # json-schema-core 9.3.2.3. additionalProperties
        if schema_content.key?('additionalProperties')
          keyword = 'additionalProperties'
          value = schema_content[keyword]
          # The value of "additionalProperties" MUST be a valid JSON Schema.
          if instance.respond_to?(:to_hash)
            results = {}
            instance.keys.each do |property_name|
              if !evaluated_property_names.include?(property_name)
                results[property_name] = subschema_validate.(subschema('additionalProperties'), instance_ptr[property_name])
              end
            end.compact
            result_validate.(
              results.values.all?(&:valid?),
              'additional instance object properties do not all validate against the `additionalProperties` schema value',
              keyword,
              results: results.values,
              annotations: [
                SchemaValidation::Annotation.new(
                  keyword: keyword,
                  value: results.keys.select do |property_name|
                    results[property_name].valid?
                  end,
                  instance_ptr: instance_ptr,
                  instance_document: instance_document,
                  schema: self,
                )
              ],
            )
          end
        end

        # json-schema-core 9.3.2.5. propertyNames
        if schema_content.key?('propertyNames')
          keyword = 'propertyNames'
          value = schema_content[keyword]
          # The value of "propertyNames" MUST be a valid JSON Schema.
          # If the instance is an object, this keyword validates if every property name in the instance validates against the provided schema. Note the property name that the schema is testing will always be a string.
          if instance.respond_to?(:to_hash)
            results = instance.keys.map do |property_name|
              subschema('propertyNames').internal_validate_instance(JSI::JSON::Pointer[], property_name, validate_only: validate_only)
            end
            result_validate.(
              results.all?(&:valid?),
              'instance object property names do not all validate against the `propertyNames` schema value',
              keyword,
              results: results,
            )
          end
        end

        # json-schema-core 9.3.1.3. unevaluatedItems
        keyword = 'unevaluatedItems'
        if schema_content.key?(keyword)
          value = schema_content[keyword]
          # The value of "unevaluatedItems" MUST be a valid JSON Schema.
          if instance.respond_to?(:to_ary)
            items_annotations = result.annotations.select do |annotation|
              annotation.instance_ptr == instance_ptr &&
                ['items', 'additionalItems', 'unevaluatedItems'].include?(annotation.keyword)
            end

            results = {}
            instance.each_index do |i|
              evaluated = items_annotations.any? do |ann|
                # true annotation value results from schema-form items, additionalItems, or unevaluatedItems.
                # integer annotation value results from array-form items
                ann.value == true || i <= ann.value
              end
              if !evaluated
                results[i] = subschema_validate.(subschema(keyword), instance_ptr[i])
              end
            end

            result_validate.(
              results.values.all?(&:valid?),
              "unevaluated instance array items did not all validate against the `#{keyword}` schema value",
              keyword,
              results: results.values,
              # If the "unevaluatedItems" subschema is applied to any positions within the instance array, it
              # produces an annotation result of boolean true, analogous to the single schema behavior of "items".
              annotations: [
                SchemaValidation::Annotation.new(
                  keyword: keyword,
                  value: true,
                  instance_ptr: instance_ptr,
                  instance_document: instance_document,
                  schema: self,
                )
              ],
            )
          end
        end

        # json-schema-core 9.3.2.4. unevaluatedProperties
        keyword = 'unevaluatedProperties'
        if schema_content.key?(keyword)
          value = schema_content[keyword]
          # The value of "unevaluatedProperties" MUST be a valid JSON Schema.
          if instance.respond_to?(:to_hash)
            properties_annotations = result.annotations.select do |annotation|
              annotation.instance_ptr == instance_ptr &&
                ['properties', 'patternProperties', 'additionalProperties', 'unevaluatedProperties'].include?(annotation.keyword)
            end

            results = {}
            instance.keys.each do |property_name|
              evaluated = properties_annotations.any? { |ann| ann.value.include?(property_name) }
              if !evaluated
                results[property_name] = subschema_validate.(subschema(keyword), instance_ptr[property_name])
              end
            end

            result_validate.(
              results.values.all?(&:valid?),
              "unevaluated instance object properties do not all validate against the `#{keyword}` schema value",
              keyword,
              results: results.values,
              annotations: [
                SchemaValidation::Annotation.new(
                  keyword: keyword,
                  value: results.keys.select do |property_name|
                    results[property_name].valid?
                  end,
                  instance_ptr: instance_ptr,
                  instance_document: instance_document,
                  schema: self,
                )
              ],
            )
          end
        end
      else
        schema_error.('schema is neither a boolean nor an object')
      end
      result.freeze
    end

    private
    def jsi_ensure_subschema_is_schema(subschema, basic_schema)
      unless subschema.is_a?(JSI::Schema)
        raise(NotASchemaError, "subschema not a schema: #{subschema.pretty_inspect}\nfrom basic schema: #{basic_schema.pretty_inspect.chomp}")
      end
    end
  end
end
