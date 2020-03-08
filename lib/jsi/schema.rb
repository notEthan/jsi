# frozen_string_literal: true

module JSI
  # JSI::Schema is a module which extends instances which represent JSON schemas.
  #
  # the content of an instance which is a JSI::Schema (referred to in this context as schema_content) is
  # expected to be a Hash (JSON object) or a Boolean.
  module Schema
    autoload :SchemaAncestorNode, 'jsi/schema/schema_ancestor_node'

    class Error < StandardError
    end

    # an exception raised when a thing is expected to be a JSI::Schema, but is not
    class NotASchemaError < Error
    end

    # JSI::Schema::DescribesSchema: a schema which describes another schema. this module
    # extends a JSI::Schema instance and indicates that JSIs which instantiate the schema
    # are themselves also schemas.
    #
    # examples of a schema which describes a schema include the draft JSON Schema metaschemas and
    # the OpenAPI schema definition which describes "A deterministic version of a JSON Schema object."
    module DescribesSchema
      # instantiates the given schema content as a JSI Schema.
      #
      # @param schema_content [#to_hash, Boolean] an object to be instantiated as a schema
      # @return [JSI::Base, JSI::Schema] a JSI whose instance is the given schema_content and whose schemas
      #   consist of this schema.
      def new_schema(schema_content, base_uri: nil)
        new_jsi(schema_content, jsi_schema_base_uri: base_uri)
      end
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
      # will be raised. schemas which describe schemas must have JSI::Schema in their
      # Schema#jsi_schema_instance_modules.
      #
      # @param schema_object [#to_hash, Boolean, JSI::Schema] an object to be instantiated as a schema.
      #   if it's already a schema, it is returned as-is.
      # @return [JSI::Schema] a JSI::Schema representing the given schema_object
      def new_schema(schema_object, base_uri: nil)
        if schema_object.is_a?(Schema)
          schema_object
        elsif schema_object.is_a?(JSI::Base)
          raise(NotASchemaError, "the given schema_object is a JSI::Base, but is not a JSI::Schema: #{schema_object.pretty_inspect.chomp}")
        elsif schema_object.respond_to?(:to_hash)
          schema_object = JSI.deep_stringify_symbol_keys(schema_object)
          if schema_object.key?('$schema') && schema_object['$schema'].respond_to?(:to_str)
            metaschema = supported_metaschemas.detect { |ms| schema_object['$schema'] == ms['$id'] || schema_object['$schema'] == ms['id'] }
            unless metaschema
              raise(NotImplementedError, "metaschema not supported: #{schema_object['$schema']}")
            end
            metaschema.new_schema(schema_object, base_uri: base_uri)
          else
            default_metaschema.new_schema(schema_object, base_uri: base_uri)
          end
        elsif [true, false].include?(schema_object)
          default_metaschema.new_schema(schema_object, base_uri: base_uri)
        else
          raise(TypeError, "cannot instantiate Schema from: #{schema_object.pretty_inspect.chomp}")
        end
      end

      # @deprecated
      alias_method :new, :new_schema

      # @deprecated
      alias_method :from_object, :new_schema
    end

    # the underlying JSON data used to instantiate this JSI::Schema.
    # this is an alias for PathedNode#jsi_node_content, named for clarity in the context of working with
    # a schema.
    def schema_content
      jsi_node_content
    end

    # @return [Addressable::URI, nil] the URI of this schema, calculated from our $id or id field
    #   resolved against our jsi_schema_base_uri
    def schema_absolute_uri
      if respond_to?(:id_without_fragment) && id_without_fragment
        jsi_schema_base_uri ? Addressable::URI.parse(jsi_schema_base_uri).join(id_without_fragment) : Addressable::URI.parse(id_without_fragment)
      end
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
          content_for_id = node_for_id.jsi_node_content
          if node_for_id.is_a?(JSI::Schema) && content_for_id.respond_to?(:to_hash)
            parent_id = content_for_id.key?('$id') && content_for_id['$id'].respond_to?(:to_str) ? content_for_id['$id'].to_str :
              content_for_id.key?('id') && content_for_id['id'].respond_to?(:to_str) ? content_for_id['id'].to_str : nil
          end

          if parent_id || node_for_id.jsi_ptr.root?
            done = true
          else
            path_from_id_node.unshift(node_for_id.jsi_ptr.reference_tokens.last)
            node_for_id = node_for_id.jsi_parent_node
          end
        end
        if parent_id
          parent_auri = Addressable::URI.parse(parent_id)
          if parent_auri.fragment
            # add onto the fragment
            parent_id_path = JSI::JSON::Pointer.from_fragment(parent_auri.fragment).reference_tokens
            path_from_id_node = parent_id_path + path_from_id_node
            parent_auri.fragment = nil
          #else: no fragment so parent_id good as is
          end

          schema_id = parent_auri.merge(fragment: JSI::JSON::Pointer.new(path_from_id_node).fragment).to_s

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

    # @return [Class subclassing JSI::Base] a JSI class (subclass of JSI::Base) representing this schema.
    def jsi_schema_class
      JSI.class_for_schemas(Set[self])
    end

    # instantiates the given instance as a JSI::Base class for schemas matched from this schema to the
    # instance.
    #
    # any parameters are passed to JSI::Base#initialize, but none are normally used.
    #
    # @param instance [Object] the JSON Schema instance to be represented as a JSI
    # @return [JSI::Base subclass] a JSI whose instance is the given instance and whose schemas are matched
    #   from this schema.
    def new_jsi(instance, *a, &b)
      JSI.class_for_schemas(match_to_instance(instance)).new(instance, *a, &b)
    end

    # @return [Boolean] does this schema itself describe a schema?
    def describes_schema?
      jsi_schema_instance_modules.any? { |m| m <= JSI::Schema } || is_a?(DescribesSchema)
    end

    # @return [Set<Module>] modules to apply to instances described by this schema. these modules are included
    #   on this schema's {#jsi_schema_module}
    def jsi_schema_instance_modules
      return @jsi_schema_instance_modules if instance_variable_defined?(:@jsi_schema_instance_modules)
      return Set[]
    end

    # @return [void]
    def jsi_schema_instance_modules=(jsi_schema_instance_modules)
      raise(TypeError) unless jsi_schema_instance_modules.is_a?(Set)
      raise(TypeError) unless jsi_schema_instance_modules.all? { |m| m.is_a?(Module) }
      @jsi_schema_instance_modules = jsi_schema_instance_modules
    end

    # a resource containing this schema.
    #
    # if any parent, or this schema itself, is a schema with an absolute uri (see #schema_absolute_uri),
    # the resource root is the closest schema with an absolute uri.
    #
    # if no parent schema has an absolute uri, the schema_resource_root is the root of the document
    # (our #jsi_root_node). in this case, the resource root may or may not be a schema itself.
    #
    # @return [JSI::Base] resource containing this schema
    def schema_resource_root
      jsi_subschema_resource_ancestors.reverse_each.detect(&:schema_resource_root?) || jsi_root_node
    end

    # @return [Boolean] is this schema the root of a schema resource?
    def schema_resource_root?
      jsi_ptr.root? || !!schema_absolute_uri
    end

    # returns a subschema of this Schema
    #
    # @param subptr [JSI::JSON::Pointer, #to_ary] a relative pointer, or array of tokens, pointing to the subschema
    # @return [JSI::Schema] the subschema at the location indicated by subptr. self if subptr is empty.
    def subschema(subptr)
      subptr = JSI::JSON::Pointer.ary_ptr(subptr)
      begin
        if subptr.empty?
          self
        elsif is_a?(MetaschemaNode::BootstrapSchema)
          self.class.new(
            jsi_document,
            jsi_ptr: jsi_ptr + subptr,
          )
        else
          subptr.evaluate(self)
        end
      end
    end

    # returns a schema in the same schema resource as this one (see #schema_resource_root) at the given
    # pointer relative to the root of the schema resource.
    #
    # @param ptr [JSI::JSON::Pointer] a pointer to a schema from our schema resource root
    # @return [JSI::Schema] the schema pointed to by ptr
    def resource_root_subschema(ptr)
      begin
        schema = self
        if schema.schema_resource_root?
          result_schema = schema.subschema(ptr)
        elsif schema.is_a?(MetaschemaNode::BootstrapSchema)
          # BootstrapSchema does not track jsi_schema_resource_ancestors used by #schema_resource_root;
          # resource_root_subschema is always relative to the document root.
          # BootstrapSchema also does not implement jsi_root_node or #[]. we instantiate the ptr directly
          # rather than as a subschema from the root.
          result_schema = schema.class.new(
            schema.jsi_document,
            jsi_ptr: ptr,
          )
        else
          result_schema = ptr.evaluate(schema.schema_resource_root)
        end
        unless result_schema.is_a?(JSI::Schema)
          raise(NotASchemaError, "subschema not a schema at ptr #{ptr.inspect}: #{result_schema.pretty_inspect.chomp}")
        end
        result_schema
      end
    end

    # checks this schema for applicators ($ref, allOf, etc.) which should be applied to the given instance.
    # returns these as a Set of {JSI::Schema}s.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param other_instance [Object] the instance to check any applicators against
    # @return [Set<JSI::Schema>] matched applicator schemas
    def match_to_instance(other_instance)
      jsi_ptr.schema_match_ptrs_to_instance(jsi_document, other_instance).map do |ptr|
        resource_root_subschema(ptr)
      end.to_set
    end

    # returns a set of subschemas of this schema for the given property name, from keywords
    #   `properties`, `patternProperties`, and `additionalProperties`.
    #
    # @param property_name [String] the property name for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given property_name
    def subschemas_for_property_name(property_name)
      jsi_memoize(:subschemas_for_property_name, property_name) do |property_name|
        jsi_ptr.schema_subschema_ptrs_for_property_name(jsi_document, property_name).map do |ptr|
          resource_root_subschema(ptr)
        end.to_set
      end
    end

    # returns a set of subschemas of this schema for the given array index, from keywords
    #   `items` and `additionalItems`.
    #
    # @param index [Integer] the array index for which to find subschemas
    # @return [Set<JSI::Schema>] subschemas of this schema for the given array index
    def subschemas_for_index(index)
      jsi_memoize(:subschemas_for_index, index) do |index|
        jsi_ptr.schema_subschema_ptrs_for_index(jsi_document, index).map do |ptr|
          resource_root_subschema(ptr)
        end.to_set
      end
    end

    # @return [Set] any object property names this schema indicates may be present on its instances.
    #   this includes any keys of this schema's "properties" object and any entries of this schema's
    #   array of "required" property keys.
    def described_object_property_names
      jsi_memoize(:described_object_property_names) do
        Set.new.tap do |property_names|
          if schema_content.respond_to?(:to_hash) && schema_content['properties'].respond_to?(:to_hash)
            property_names.merge(schema_content['properties'].keys)
          end
          if schema_content.respond_to?(:to_hash) && schema_content['required'].respond_to?(:to_ary)
            property_names.merge(schema_content['required'].to_ary)
          end
        end
      end
    end

    # @return [Array] array of schema validation errors for
    #   the given instance against this schema
    def fully_validate_instance(other_instance, errors_as_objects: false)
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(jsi_document), JSI::Typelike.as_json(other_instance), fragment: jsi_ptr.fragment, errors_as_objects: errors_as_objects)
    end

    # @return [true, false] whether the given instance validates against this schema
    def validate_instance(other_instance)
      ::JSON::Validator.validate(JSI::Typelike.as_json(jsi_document), JSI::Typelike.as_json(other_instance), fragment: jsi_ptr.fragment)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate the instance is valid against this schema
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors against this schema
    def validate_instance!(other_instance)
      ::JSON::Validator.validate!(JSI::Typelike.as_json(jsi_document), JSI::Typelike.as_json(other_instance), fragment: jsi_ptr.fragment)
    end

    # @return [Array] array of schema validation errors for
    #   this schema, validated against its metaschema. a default metaschema
    #   is assumed if the schema does not specify a $schema.
    def fully_validate_schema(errors_as_objects: false)
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(jsi_document), [], fragment: jsi_ptr.fragment, validate_schema: true, list: true, errors_as_objects: errors_as_objects)
    end

    # @return [true, false] whether this schema validates against its metaschema
    def validate_schema
      ::JSON::Validator.validate(JSI::Typelike.as_json(jsi_document), [], fragment: jsi_ptr.fragment, validate_schema: true, list: true)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate this schema is valid against its metaschema
    # @raise [::JSON::Schema::ValidationError] raises if this schema has
    #   validation errors against its metaschema
    def validate_schema!
      ::JSON::Validator.validate!(JSI::Typelike.as_json(jsi_document), [], fragment: jsi_ptr.fragment, validate_schema: true, list: true)
    end

    # @private
    # @return [Addressable::URI, nil] the base URI for any subschemas below this schema.
    #   this is always an absolute URI (with no fragment).
    def jsi_subschema_base_uri
      if schema_absolute_uri
        schema_absolute_uri
      else
        jsi_schema_base_uri
      end
    end

    # @private
    # @return [Array<JSI::Schema>] schema resources which are ancestors of any subschemas below this schema.
    #   this may include this JSI if this is a schema resource root.
    def jsi_subschema_resource_ancestors
      if schema_resource_root?
        jsi_schema_resource_ancestors + [self]
      else
        jsi_schema_resource_ancestors
      end
    end
  end
end
