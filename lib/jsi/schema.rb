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
              MetaschemaNode.new(schema_object)
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

    # @return [String, nil] an absolute id for the schema, with a json pointer fragment. nil if
    #   no parent of this schema defines an id.
    def schema_id
      return @schema_id if instance_variable_defined?(:@schema_id)
      @schema_id = begin
        # start from self and ascend parents looking for an 'id' property.
        # append a fragment to that id (appending to an existing fragment if there
        # is one) consisting of the path from that parent to our schema_node.
        node_for_id = self
        path_from_id_node = []
        done = false

        while !done
          node_content_for_id = node_for_id.node_content
          if node_for_id.is_a?(JSI::Schema) && node_content_for_id.respond_to?(:to_hash)
            parent_id = node_content_for_id.key?('$id') && node_content_for_id['$id'].respond_to?(:to_str) ? node_content_for_id['$id'].to_str :
              node_content_for_id.key?('id') && node_content_for_id['id'].respond_to?(:to_str) ? node_content_for_id['id'].to_str : nil
          end

          if parent_id || node_for_id.node_ptr.root?
            done = true
          else
            path_from_id_node.unshift(node_for_id.node_ptr.reference_tokens.last)
            node_for_id = node_for_id.parent_node
          end
        end
        if parent_id
          parent_auri = Addressable::URI.parse(parent_id)
          if parent_auri.fragment
            # add onto the fragment
            parent_id_path = JSI::JSON::Pointer.from_fragment('#' + parent_auri.fragment).reference_tokens
            path_from_id_node = parent_id_path + path_from_id_node
            parent_auri.fragment = nil
          #else: no fragment so parent_id good as is
          end

          fragment = JSI::JSON::Pointer.new(path_from_id_node).fragment
          schema_id = parent_auri.to_s + fragment

          schema_id
        else
          nil
        end
      end
    end

    # @return [Module] a module representing this schema. see {JSI::SchemaClasses.module_for_schema}.
    def jsi_schema_module
      JSI::SchemaClasses.module_for_schema(self)
    end

    # @return [Class subclassing JSI::Base] shortcut for JSI.class_for_schema(schema)
    def jsi_schema_class
      JSI.class_for_schema(self)
    end

    # calls #new on the class for this schema with the given arguments. for parameters,
    # see JSI::Base#initialize documentation.
    #
    # @return [JSI::Base] a JSI whose schema is this schema and whose instance is the given instance
    def new_jsi(other_instance, *a, &b)
      JSI.class_for_schema(match_to_instance(other_instance)).new(other_instance, *a, &b)
    end

    # @return [Boolean] does this schema itself describe a schema?
    def describes_schema?
      is_a?(JSI::Schema::DescribesSchema)
    end

    # if this schema is a oneOf, allOf, anyOf schema, #match_to_instance finds
    # one of the subschemas that matches the given instance and returns it. if
    # there are no matching *Of schemas, this schema is returned.
    #
    # @param other_instance [Object] the instance to which to attempt to match *Of subschemas
    # @return [JSI::Schema] a matched subschema, or this schema (self)
    def match_to_instance(other_instance)
      ptr = node_ptr
      ptr = ptr.deref(node_document)
      ptr = ptr.schema_match_ptr_to_instance(node_document, other_instance)
      if ptr
        ptr.evaluate(document_root_node).tap { |subschema| jsi_ensure_subschema_is_schema(subschema, ptr) }
      else
        self
      end
    end

    # @param property_name [String] the property name for which to find a subschema
    # @return [JSI::Schema, nil] a subschema from `properties`, `patternProperties`, or `additionalProperties` for the given token
    def subschema_for_property(property_name)
      jsi_memoize(:subschema_for_property, property_name) do |property_name|
        ptr = node_ptr
        ptr = ptr.deref(node_document)
        ptr = ptr.schema_subschema_ptr_for_property_name(node_document, property_name)
        if ptr
          ptr = ptr.deref(node_document)
          ptr.evaluate(document_root_node).tap { |subschema| jsi_ensure_subschema_is_schema(subschema, ptr) }
        else
          nil
        end
      end
    end

    # @param index [Integer] the array index for which to find a subschema
    # @return [JSI::Schema, nil] a subschema from `items` or `additionalItems` for the given token
    def subschema_for_index(index)
      jsi_memoize(:subschema_for_index, index) do |index|
        ptr = node_ptr
        ptr = ptr.deref(node_document)
        ptr = ptr.schema_subschema_ptr_for_index(node_document, index)
        if ptr
          ptr = ptr.deref(node_document)
          ptr.evaluate(document_root_node).tap { |subschema| jsi_ensure_subschema_is_schema(subschema, ptr) }
        else
          nil
        end
      end
    end

    # @return [Set] any object property names this schema indicates may be
    #   present on its instances. this includes, if present: keys of this
    #   schema's "properties" object; entries of this schema's array of
    #   "required" property keys. if this schema has allOf subschemas, those
    #   schemas are checked (recursively) for their described object property names.
    def described_object_property_names
      jsi_memoize(:described_object_property_names) do
        Set.new.tap do |property_names|
          if node_content.respond_to?(:to_hash) && node_content['properties'].respond_to?(:to_hash)
            property_names.merge(node_content['properties'].keys)
          end
          if node_content.respond_to?(:to_hash) && node_content['required'].respond_to?(:to_ary)
            property_names.merge(node_content['required'].to_ary)
          end
          # we should look at dependencies (TODO).
          if respond_to?(:to_hash) && self['allOf'].respond_to?(:to_ary)
            self['allOf'].select{ |s| s.is_a?(JSI::Schema) }.map(&:deref).map do |allOf_schema|
              property_names.merge(allOf_schema.described_object_property_names)
            end
          end
        end
      end
    end

    # @return [Array] array of schema validation errors for
    #   the given instance against this schema
    def fully_validate_instance(other_instance, errors_as_objects: false)
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(node_document), JSI::Typelike.as_json(other_instance), fragment: node_ptr.fragment, errors_as_objects: errors_as_objects)
    end

    # @return [true, false] whether the given instance validates against this schema
    def validate_instance(other_instance)
      ::JSON::Validator.validate(JSI::Typelike.as_json(node_document), JSI::Typelike.as_json(other_instance), fragment: node_ptr.fragment)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate the instance is valid against this schema
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors against this schema
    def validate_instance!(other_instance)
      ::JSON::Validator.validate!(JSI::Typelike.as_json(node_document), JSI::Typelike.as_json(other_instance), fragment: node_ptr.fragment)
    end

    # @return [Array] array of schema validation errors for
    #   this schema, validated against its metaschema. a default metaschema
    #   is assumed if the schema does not specify a $schema.
    def fully_validate_schema(errors_as_objects: false)
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(node_document), [], fragment: node_ptr.fragment, validate_schema: true, list: true, errors_as_objects: errors_as_objects)
    end

    # @return [true, false] whether this schema validates against its metaschema
    def validate_schema
      ::JSON::Validator.validate(JSI::Typelike.as_json(node_document), [], fragment: node_ptr.fragment, validate_schema: true, list: true)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate this schema is valid against its metaschema
    # @raise [::JSON::Schema::ValidationError] raises if this schema has
    #   validation errors against its metaschema
    def validate_schema!
      ::JSON::Validator.validate!(JSI::Typelike.as_json(node_document), [], fragment: node_ptr.fragment, validate_schema: true, list: true)
    end

    private
    def jsi_ensure_subschema_is_schema(subschema, ptr)
      unless subschema.is_a?(JSI::Schema)
        raise(NotASchemaError, "subschema not a schema at ptr #{ptr.inspect}: #{subschema.pretty_inspect.chomp}")
      end
    end
  end
end
