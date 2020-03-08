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

    include Util::Memoize

    # JSI::Schema::DescribesSchema: a schema which describes another schema. this module
    # extends a JSI::Schema instance and indicates that JSIs which instantiate the schema
    # are themselves also schemas.
    #
    # examples of a schema which describes a schema include the draft JSON Schema metaschemas and
    # the OpenAPI schema definition which describes "A deterministic version of a JSON Schema object."
    module DescribesSchema
    end

    class << self
      # @return [JSI::Schema] the default metaschema
      def default_metaschema
        JSI::JSONSchemaOrgDraft06.schema
      end

      # @return [Array<JSI::Schema>] supported metaschemas
      def supported_metaschemas
        [
          JSI::JSONSchemaOrgDraft04.schema,
          JSI::JSONSchemaOrgDraft06.schema,
          JSI::JSONSchemaOrgDraft201909.schema,
        ]
      end

      # instantiates a given schema object as a JSI::Schema.
      #
      # schemas are instantiated according to their '$schema' property if specified. otherwise their schema
      # will be the {JSI::Schema.default_metaschema}.
      #
      # if the given schema_object is a JSI::Base but not already a JSI::Schema, an error
      # will be raised. JSI::Base _should_ already extend a given instance with JSI::Schema
      # when its schema describes a schema (by extending with JSI::Schema::DescribesSchema).
      #
      # @param schema_object [#to_hash, Boolean, JSI::Schema] an object to be instantiated as a schema.
      #   if it's already a schema, it is returned as-is.
      # @return [JSI::Schema] a JSI::Schema representing the given schema_object
      def from_object(schema_object)
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
              metaschema.new_jsi(schema_object)
            end
          else
            default_metaschema.new_jsi(schema_object)
          end
        elsif [true, false].include?(schema_object)
          default_metaschema.new_jsi(schema_object)
        else
          raise(TypeError, "cannot instantiate Schema from: #{schema_object.pretty_inspect.chomp}")
        end
      end

      alias_method :new, :from_object
    end

    # @return [String, nil] the id of this schema, if any is specified, according to the $id field
    #   or (with older json schema drafts) the id field.
    def id
      dopn = jsi_schemas.map(&:described_object_property_names).inject(Set.new, &:|)
      idk = %w($id id).detect { |k| dopn.include?(k) }
      if idk
        content = jsi_node_content
        if content.key?(idk)
          if content[idk].respond_to?(:to_str)
            content[idk].to_str
          else
            # invalid non-string in the id field
            nil
          end
        else
          nil
        end
      else
        # this should not ever happen
        nil
      end
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
      JSI::SchemaClasses.module_for_schema(self)
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
    # - if the instantiated JSI is a {JSI::Schema}, it is registered with `JSI.registered_schemas` (a {JSI::SchemaRegistry})
    #
    # @param schema_id [#to_str]
    # @return [JSI::Base] a JSI whose instance is the given instance and whose schemas are matched from this
    #   schema.
    def new_jsi(other_instance, schema_id: nil, **a, &b)
      JSI.class_for_schemas(match_to_instance(other_instance)).new(other_instance, a, &b).tap do |jsi|
        if jsi.is_a?(Schema)
          jsi.jsi_register_schema(schema_id: schema_id)
        end
      end
    end

    def jsi_register_schema(schema_id: nil)
      JSI.registered_schemas.register(self, schema_id: schema_id)
    end

    # @return [Boolean] does this schema itself describe a schema?
    def describes_schema?
      is_a?(JSI::Schema::DescribesSchema)
    end

    # @return [BasicSchema]
    def own_basic_schema
      jsi_memoize(__method__) do
        BasicSchema.new(jsi_ptr, jsi_document)
      end
    end

    # checks this schema for relevant applicators ($ref, allOf, anyOf, oneOf), and returns  an Enumerable
    # containing each resulting JSI::Schema. if no applicators apply, the only schema returned will be self.
    #
    # @param other_instance [Object] the instance to which to attempt to match *Of subschemas
    # @return [Enumerable<JSI::Schema>] matched applicator subschemas
    def match_to_instance(other_instance, visited_refs: [], matched: Set[])
      Set.new.tap do |schemas|
        schema = self

        if schema.respond_to?(:to_hash)
          if schema['$ref'].respond_to?(:to_str)
            keyword = '$ref'
            ref = SchemaRef.new(own_basic_schema, keyword)

            if visited_refs.include?(ref)
              schemas << self
            else
              deref_schema = ref.deref_schema(self)
              schemas.merge(deref_schema.match_to_instance(other_instance, visited_refs: visited_refs + [ref]))
            end
          end
          if schema['$recursiveRef'].respond_to?(:to_str)
            keyword = '$recursiveRef'
            ref = SchemaRef.new(own_basic_schema, keyword)
            if visited_refs.include?(ref)
              schemas << self
            else
              deref_schema = ref.deref_schema(self)
              schemas.merge(deref_schema.match_to_instance(other_instance, visited_refs: visited_refs + [ref]))
            end
          end
          unless ref
            schemas << self
          end
          if schema['allOf'].respond_to?(:to_ary)
            schema['allOf'].each_index do |i|
              schemas.merge(schema['allOf'][i].match_to_instance(other_instance, visited_refs: visited_refs))
            end
          end
          if schema['anyOf'].respond_to?(:to_ary)
            schema['anyOf'].each_index do |i|
              valid = schema['anyOf'][i].jsi_instance_valid?(other_instance)
              if valid
                schemas.merge(schema['anyOf'][i].match_to_instance(other_instance, visited_refs: visited_refs))
              end
            end
          end
          if schema['oneOf'].respond_to?(:to_ary)
            one_i = schema['oneOf'].each_index.detect do |i|
              schema['oneOf'][i].jsi_instance_valid?(other_instance)
            end
            if one_i
              schemas.merge(schema['oneOf'][one_i].match_to_instance(other_instance, visited_refs: visited_refs))
            end
          end
          # TODO dependencies
        else
          schemas << self
        end
      end
    end

    # @param property_name [String] the property name for which to find subschemas
    # @return [Enumerable<JSI::Schema>] subschemas of this schema for the given property_name, using
    #   `properties`, `patternProperties`, and `additionalProperties`
    def subschemas_for_property(property_name)
      jsi_memoize(:subschemas_for_property, property_name) do |property_name|
        own_basic_schema.subschemas_for_property_name(property_name).map do |sub_basic_schema|
          sub_basic_schema.ptr.evaluate(jsi_root_node).tap { |subschema| jsi_ensure_subschema_is_schema(subschema, sub_basic_schema) }
        end
      end
    end

    # @param index [Integer] the array index for which to find subschemas
    # @return [Enumerable<JSI::Schema>] subschemas of this schema for the given array index, using
    #   `items` and `additionalItems`
    def subschemas_for_index(index)
      jsi_memoize(:subschemas_for_index, index) do |index|
        own_basic_schema.subschemas_for_index(index).map do |sub_basic_schema|
          sub_basic_schema.ptr.evaluate(jsi_root_node).tap { |subschema| jsi_ensure_subschema_is_schema(subschema, sub_basic_schema) }
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
      own_basic_schema.validate(instance_ptr, instance_document)
    end

    # @return [Boolean]
    def instance_valid?(instance)
      if instance.is_a?(JSI::PathedNode)
        instance = instance.jsi_node_content
      end
      own_basic_schema.valid?(instance)
    end

    private
    def jsi_ensure_subschema_is_schema(subschema, basic_schema)
      unless subschema.is_a?(JSI::Schema)
        raise(NotASchemaError, "subschema not a schema: #{subschema.pretty_inspect}\nfrom basic schema: #{basic_schema.pretty_inspect.chomp}")
      end
    end
  end
end
