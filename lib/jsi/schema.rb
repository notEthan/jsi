# frozen_string_literal: true

module JSI
  # JSI::Schema is a module which extends instances which represent JSON schemas.
  #
  # the content of an instance which is a JSI::Schema (referred to in this context as schema_content) is
  # expected to be a Hash (JSON object) or a Boolean.
  module Schema
    autoload :Application, 'jsi/schema/application'
    autoload :Validation, 'jsi/schema/validation'
    autoload :Issue, 'jsi/schema/issue'

    autoload :SchemaAncestorNode, 'jsi/schema/schema_ancestor_node'

    autoload :Ref, 'jsi/schema/ref'

    autoload :Draft04, 'jsi/schema/draft04'
    autoload :Draft06, 'jsi/schema/draft06'
    autoload :Draft07, 'jsi/schema/draft07'

    class Error < StandardError
    end

    # an exception raised when a thing is expected to be a JSI::Schema, but is not
    class NotASchemaError < Error
    end

    # an exception raised when we are unable to resolve a schema reference
    class ReferenceError < StandardError
    end

    # extends any schema which uses the keyword '$id' to identify its canonical URI
    module BigMoneyId
      # @return [#to_str, nil] the contents of a $id keyword whose value is a string, or nil
      def id
        if schema_content.respond_to?(:to_hash) && schema_content['$id'].respond_to?(:to_str)
          schema_content['$id']
        else
          nil
        end
      end
    end

    # extends any schema which uses the keyword 'id' to identify its canonical URI
    module OldId
      # @return [#to_str, nil] the contents of an id keyword whose value is a string, or nil
      def id
        if schema_content.respond_to?(:to_hash) && schema_content['id'].respond_to?(:to_str)
          schema_content['id']
        else
          nil
        end
      end
    end

    # extends any schema which defines an anchor as a URI fragment in the schema id
    module IdWithAnchor
      # @return [Addressable::URI, nil] a URI for the schema's id, unless the id defines an anchor in its
      #   fragment. nil if the schema defines no id.
      def id_without_fragment
        if id
          id_uri = Addressable::URI.parse(id)
          if id_uri.merge(fragment: nil).empty?
            # fragment-only id is just an anchor
            # e.g. #foo
            nil
          elsif id_uri.fragment == nil
            # no fragment
            # e.g. http://localhost:1234/bar
            id_uri
          elsif id_uri.fragment == ''
            # empty fragment
            # e.g. http://json-schema.org/draft-07/schema#
            id_uri.merge(fragment: nil)
          elsif jsi_schema_base_uri && jsi_schema_base_uri.join(id_uri).merge(fragment: nil) == jsi_schema_base_uri
            # the id, resolved against the base uri, consists of the base uri plus an anchor fragment.
            # so there's no non-fragment id.
            # e.g. base uri is http://localhost:1234/bar
            #        and id is http://localhost:1234/bar#foo
            nil
          else
            # e.g. http://localhost:1234/bar#foo
            id_uri.merge(fragment: nil)
          end
        else
          nil
        end
      end

      # @return [String] an anchor defined by a non-empty fragment in the id uri
      def anchor
        if id
          id_uri = Addressable::URI.parse(id)
          if id_uri.fragment == ''
            nil
          else
            id_uri.fragment
          end
        else
          nil
        end
      end
    end

    # @private
    module IntegerAllows0Fraction
      # @private
      # @param value
      # @return [Boolean] is value an integer?
      def internal_integer?(value)
        value.is_a?(Integer) || (value.is_a?(Numeric) && value % 1.0 == 0.0)
      end
    end

    # @private
    module IntegerDisallows0Fraction
      # @private
      # @param value
      # @return [Boolean] is value an integer?
      def internal_integer?(value)
        value.is_a?(Integer)
      end
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
      # the schema is instantiated after recursively converting any symbol hash keys in the structure
      # to strings. note that this is in contrast to {JSI::Schema#new_jsi}, which does not alter its
      # given instance.
      #
      # the schema will be registered with the `JSI.schema_registry`.
      #
      # @param schema_content [#to_hash, Boolean] an object to be instantiated as a schema
      # @param base_uri [nil, #to_str, Addressable::URI] the URI of the schema document.
      #   relative URIs within the document are resolved using this base_uri.
      #   the result schema will be registered with this URI in the {JSI.schema_registry}.
      # @return [JSI::Base, JSI::Schema] a JSI whose instance is the given schema_content and whose schemas
      #   are inplace applicators matched from self to the schema being instantiated.
      def new_schema(schema_content, base_uri: nil)
        new_jsi(Util.deep_stringify_symbol_keys(schema_content),
          base_uri: base_uri,
        ).tap(&:register_schema)
      end

      # instantiates a given schema object as a JSI Schema and returns its JSI Schema Module.
      #
      # see {.new_schema}
      #
      # @param (see .new_schema)
      # @return [Module, JSI::SchemaModule] the JSI Schema Module of the schema
      def self.new_schema_module(schema_content, **kw)
        new_schema(schema_content, **kw).jsi_schema_module
      end
    end

    class << self
      # @return [JSI::Schema] the default metaschema
      def default_metaschema
        JSI::JSONSchemaOrgDraft06.schema
      end

      # instantiates a given schema object as a JSI Schema.
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
      # @param base_uri (see DescribesSchema#new_schema)
      # @return [JSI::Schema] a JSI::Schema representing the given schema_object
      def new_schema(schema_object, base_uri: nil)
        if schema_object.is_a?(Schema)
          schema_object
        elsif schema_object.is_a?(JSI::Base)
          raise(NotASchemaError, "the given schema_object is a JSI::Base, but is not a JSI::Schema: #{schema_object.pretty_inspect.chomp}")
        elsif schema_object.respond_to?(:to_hash)
          if schema_object.key?('$schema') && schema_object['$schema'].respond_to?(:to_str)
            metaschema = Schema::Ref.new(schema_object['$schema']).deref_schema
            unless metaschema.is_a?(Schema) && metaschema.describes_schema?
              raise(Schema::ReferenceError, "given schema_object contains a $schema but the resource it identifies does not describe a schema")
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

      # ensure the given object is a JSI Schema
      #
      # @param schema [Object] the thing the caller wishes to ensure is a Schema
      # @param msg [#to_s, #to_ary] lines of the error message preceding the pretty-printed schema param
      #   if the schema param is not a schema
      # @raise [NotASchemaError] if the schema param is not a schema
      # @return [Schema] the given schema
      def ensure_schema(schema, msg: "indicated object is not a schema:", reinstantiate_as: nil)
        if schema.is_a?(Schema)
          schema
        else
          if reinstantiate_as
            # TODO warn; behavior is undefined and I hate this implementation

            result_schema_schemas = schema.jsi_schemas + reinstantiate_as

            result_schema_class = JSI::SchemaClasses.class_for_schemas(result_schema_schemas)

            result_schema_class.new(Base::NOINSTANCE,
              jsi_document: schema.jsi_document,
              jsi_ptr: schema.jsi_ptr,
              jsi_root_node: schema.jsi_root_node,
              jsi_schema_base_uri: schema.jsi_schema_base_uri,
              jsi_schema_resource_ancestors: schema.jsi_schema_resource_ancestors,
            )
          else
            raise(NotASchemaError, [
              *msg,
              schema.pretty_inspect.chomp,
            ].join("\n"))
          end
        end
      end
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
        if jsi_schema_base_uri
          Addressable::URI.parse(jsi_schema_base_uri).join(id_without_fragment)
        elsif id_without_fragment.absolute?
          id_without_fragment
        else
          # TODO warn / schema_error
          nil
        end
      end
    end

    # @return [Addressable::URI, nil] a URI which refers to this schema.
    #   nil if no parent of this schema defines an id.
    #   see {#schema_uris} for all URIs known to refer to this schema.
    def schema_uri
      schema_uris.first
    end

    # @return [Array<Addressable::URI>] URIs which refer to this schema
    def schema_uris
      jsi_memoize(:schema_uris) do
        each_schema_uri.to_a
      end
    end

    # @yield [Addressable::URI] each URI which refers to this schema
    def each_schema_uri
      return to_enum(__method__) unless block_given?

      yield schema_absolute_uri if schema_absolute_uri

      parent_schemas = jsi_subschema_resource_ancestors.reverse_each.select do |resource|
        resource.is_a?(Schema) && resource.schema_absolute_uri
      end

      parent_schemas.each do |parent_schema|
        relative_ptr = self.jsi_ptr.ptr_relative_to(parent_schema.jsi_ptr)
        yield parent_schema.schema_absolute_uri.merge(fragment: relative_ptr.fragment)
      end

      nil
    end

    # a module which extends all instances of this schema. this may be opened by the application to add
    # methods to schema instances.
    #
    # this module includes accessor methods for object property names this schema
    # describes (see {#described_object_property_names}). these accessors wrap {Base#[]} and {Base#[]=}.
    #
    # some functionality is also defined on the module itself (its singleton class, not for its instances):
    #
    # - the module is extended with {JSI::SchemaModule}, which defines .new_jsi to instantiate instances
    #   of this schema (see {#new_jsi}).
    # - properties described by this schema's metaschema are defined as methods to get subschemas' schema
    #   modules, so for example `schema.jsi_schema_module.items` returns the same module
    #   as `schema.items.jsi_schema_module`.
    # - method .schema which returns this schema.
    #
    # @return [Module]
    def jsi_schema_module
      JSI::SchemaClasses.module_for_schema(self)
    end

    # @return [Class subclassing JSI::Base] a JSI class (subclass of JSI::Base) representing this schema.
    def jsi_schema_class
      JSI::SchemaClasses.class_for_schemas(SchemaSet[self])
    end

    # instantiates the given instance as a JSI::Base class for schemas matched from this schema to the
    # instance.
    #
    # @param instance [Object] the JSON Schema instance to be represented as a JSI
    # @param base_uri (see SchemaSet#new_jsi)
    # @return [JSI::Base subclass] a JSI whose instance is the given instance and whose schemas are matched
    #   from this schema.
    def new_jsi(instance,
        base_uri: nil
    )
      SchemaSet[self].new_jsi(instance, base_uri: base_uri)
    end

    # registers this schema with `JSI.schema_registry`
    #
    # @return [void]
    def register_schema
      JSI.schema_registry.register(self)
    end

    # @return [Boolean] does this schema itself describe a schema?
    def describes_schema?
      jsi_schema_instance_modules.any? { |m| m <= JSI::Schema }
    end

    # @return [Set<Module>] modules to apply to instances described by this schema. these modules are included
    #   on this schema's {#jsi_schema_module}
    def jsi_schema_instance_modules
      return @jsi_schema_instance_modules if instance_variable_defined?(:@jsi_schema_instance_modules)
      return Set[].freeze
    end

    # @return [void]
    def jsi_schema_instance_modules=(jsi_schema_instance_modules)
      @jsi_schema_instance_modules = Util.ensure_module_set(jsi_schema_instance_modules)
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
    # @param subptr [JSI::Ptr, #to_ary] a relative pointer, or array of tokens, pointing to the subschema
    # @return [JSI::Schema] the subschema at the location indicated by subptr. self if subptr is empty.
    def subschema(subptr)
      subschema_map[Ptr.ary_ptr(subptr)]
    end

    private

    def subschema_map
      jsi_memomap(:subschema) do |subptr|
        if is_a?(MetaschemaNode::BootstrapSchema)
          self.class.new(
            jsi_document,
            jsi_ptr: jsi_ptr + subptr,
            jsi_schema_base_uri: jsi_resource_ancestor_uri,
          )
        else
          Schema.ensure_schema(subptr.evaluate(self, as_jsi: true), msg: [
            "subschema is not a schema at pointer: #{subptr.pointer}"
          ])
        end
      end
    end

    public

    # returns a schema in the same schema resource as this one (see #schema_resource_root) at the given
    # pointer relative to the root of the schema resource.
    #
    # @param ptr [JSI::Ptr, #to_ary] a pointer to a schema from our schema resource root
    # @return [JSI::Schema] the schema pointed to by ptr
    def resource_root_subschema(ptr)
      resource_root_subschema_map[Ptr.ary_ptr(ptr)]
    end

    private

    def resource_root_subschema_map
      jsi_memomap(:resource_root_subschema_map) do |ptr|
        schema = self
        if schema.is_a?(MetaschemaNode::BootstrapSchema)
          # BootstrapSchema does not track jsi_schema_resource_ancestors used by #schema_resource_root;
          # resource_root_subschema is always relative to the document root.
          # BootstrapSchema also does not implement jsi_root_node or #[]. we instantiate the ptr directly
          # rather than as a subschema from the root.
          schema.class.new(
            schema.jsi_document,
            jsi_ptr: ptr,
            jsi_schema_base_uri: nil,
          )
        else
          resource_root = schema.schema_resource_root
          Schema.ensure_schema(ptr.evaluate(resource_root, as_jsi: true),
            msg: [
              "subschema is not a schema at pointer: #{ptr.pointer}"
            ],
            reinstantiate_as: schema.jsi_schemas.select(&:describes_schema?)
          )
        end
      end
    end

    public

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
        end.freeze
      end
    end

    # validates the given instance against this schema
    #
    # @param instance [Object] the instance to validate against this schema
    # @return [JSI::Validation::Result]
    def instance_validate(instance)
      if instance.is_a?(JSI::PathedNode)
        instance_ptr = instance.jsi_ptr
        instance_document = instance.jsi_document
      else
        instance_ptr = Ptr[]
        instance_document = instance
      end
      internal_validate_instance(instance_ptr, instance_document)
    end

    # @param instance [Object] the instance to validate against this schema
    # @return [Boolean] whether the given instance is valid against this schema
    def instance_valid?(instance)
      if instance.is_a?(JSI::PathedNode)
        instance = instance.jsi_node_content
      end
      internal_validate_instance(Ptr[], instance, validate_only: true).valid?
    end

    # @private
    def fully_validate_instance(other_instance, errors_as_objects: false)
      raise(NotImplementedError, "Schema#fully_validate_instance removed: see new validation interface Schema#instance_validate")
    end

    # @private
    def validate_instance(other_instance)
      raise(NotImplementedError, "Schema#validate_instance renamed: see Schema#instance_valid?")
    end

    # @private
    def validate_instance!(other_instance)
      raise(NotImplementedError, "Schema#validate_instance! removed")
    end

    # @private
    def fully_validate_schema(errors_as_objects: false)
      raise(NotImplementedError, "Schema#fully_validate_schema removed: use validation interface Base#jsi_validate on the schema")
    end

    # @private
    def validate_schema
      raise(NotImplementedError, "Schema#validate_schema removed: use validation interface Base#jsi_valid? on the schema")
    end

    # @private
    def validate_schema!
      raise(NotImplementedError, "Schema#validate_schema! removed")
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
