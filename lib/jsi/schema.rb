# frozen_string_literal: true

module JSI
  # JSI::Schema is a module which extends {JSI::Base} instances which represent JSON schemas.
  #
  # This module is included on the {Schema#jsi_schema_module JSI Schema module} of any schema
  # which describes other schemas, i.e. is a metaschema or other {Schema::DescribesSchema}.
  # Therefore, any JSI instance described by a schema which is a {Schema::DescribesSchema} is
  # a schema and is extended by this module.
  #
  # The content of an instance which is a JSI::Schema (referred to in this context as schema_content) is
  # typically a Hash (JSON object) or a boolean.
  module Schema
    autoload :Application, 'jsi/schema/application'
    autoload :Validation, 'jsi/schema/validation'

    autoload :Issue, 'jsi/schema/issue'
    autoload :Ref, 'jsi/schema/ref'

    autoload :SchemaAncestorNode, 'jsi/schema/schema_ancestor_node'

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
      # the contents of a $id keyword whose value is a string, or nil
      # @return [#to_str, nil]
      def id
        if keyword?('$id') && schema_content['$id'].respond_to?(:to_str)
          schema_content['$id']
        else
          nil
        end
      end
    end

    # extends any schema which uses the keyword 'id' to identify its canonical URI
    module OldId
      # the contents of an `id` keyword whose value is a string, or nil
      # @return [#to_str, nil]
      def id
        if keyword?('id') && schema_content['id'].respond_to?(:to_str)
          schema_content['id']
        else
          nil
        end
      end
    end

    # extends any schema which defines an anchor as a URI fragment in the schema id
    module IdWithAnchor
      # a URI for the schema's id, unless the id defines an anchor in its
      # fragment. nil if the schema defines no id.
      # @return [Addressable::URI, nil]
      def id_without_fragment
        if id
          id_uri = Util.uri(id)
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
            id_uri.merge(fragment: nil).freeze
          elsif jsi_schema_base_uri && jsi_schema_base_uri.join(id_uri).merge(fragment: nil) == jsi_schema_base_uri
            # the id, resolved against the base uri, consists of the base uri plus an anchor fragment.
            # so there's no non-fragment id.
            # e.g. base uri is http://localhost:1234/bar
            #        and id is http://localhost:1234/bar#foo
            nil
          else
            # e.g. http://localhost:1234/bar#foo
            id_uri.merge(fragment: nil).freeze
          end
        else
          nil
        end
      end

      # an anchor defined by a non-empty fragment in the id uri
      # @return [String]
      def anchor
        if id
          id_uri = Util.uri(id)
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
      # is `value` an integer?
      # @private
      # @param value
      # @return [Boolean]
      def internal_integer?(value)
        value.is_a?(Integer) || (value.is_a?(Numeric) && value % 1.0 == 0.0)
      end
    end

    # @private
    module IntegerDisallows0Fraction
      # is `value` an integer?
      # @private
      # @param value
      # @return [Boolean]
      def internal_integer?(value)
        value.is_a?(Integer)
      end
    end

    # This module extends any JSI Schema which describes schemas.
    #
    # Examples of a schema which describes schemas include the JSON Schema metaschemas and
    # the OpenAPI schema definition which describes "A deterministic version of a JSON Schema object."
    #
    # Schemas which describes schemas include {JSI::Schema} in their
    # {Schema#jsi_schema_module JSI Schema module}, so for a schema which is an instance of
    # DescribesSchema, instances of that schema are instances of {JSI::Schema} and are schemas.
    #
    # A schema is indicated as describing other schemas using the {Schema#describes_schema!} method.
    module DescribesSchema
      # Instantiates the given schema content as a JSI Schema.
      #
      # the schema will be registered with the `JSI.schema_registry`.
      #
      # By default, the `schema_content` will have any Symbol keys of Hashes replaced with Strings
      # (recursively through the document). This is controlled by the param `stringify_symbol_keys`.
      #
      # @param schema_content an object to be instantiated as a JSI Schema - typically a Hash
      # @param uri [nil, #to_str, Addressable::URI] The retrieval URI of the schema document.
      #
      #   It is rare that this needs to be specified. Most schemas, if they use absolute URIs, will
      #   use the `$id` keyword (`id` in draft 4) to specify this. A different retrieval URI is useful
      #   in unusual cases:
      #
      #     - A schema in the document uses relative URIs for `$id` or `$ref` without an absolute id in an
      #       ancestor schema - these will be resolved relative to this URI
      #     - Another schema refers with `$ref` to the schema being instantiated by this retrieval URI,
      #       rather than an id declared in the schema - the schema is resolvable by this URI in the
      #       {JSI::SchemaRegistry}.
      # @param stringify_symbol_keys [Boolean] Whether the schema content will have any Symbol keys of Hashes
      #   replaced with Strings (recursively through the document).
      #   Replacement is done on a copy; the given schema content is not modified.
      # @return [JSI::Base subclass + JSI::Schema] a JSI which is a {JSI::Schema} whose content comes from
      #   the given `schema_content` and whose schemas are this schema's inplace applicators.
      def new_schema(schema_content,
          uri: nil,
          stringify_symbol_keys: true
      )
        schema_jsi = new_jsi(schema_content,
          uri: uri,
          stringify_symbol_keys: stringify_symbol_keys,
        )
        JSI.schema_registry.register(schema_jsi)
        schema_jsi
      end

      # Instantiates the given schema content as a JSI Schema, passing all params to
      # {Schema::DescribesSchema#new_schema}, and returns its {Schema#jsi_schema_module JSI Schema Module}.
      #
      # @return [Module + JSI::SchemaModule]
      def new_schema_module(schema_content, **kw)
        new_schema(schema_content, **kw).jsi_schema_module
      end
    end

    class << self
      def extended(o)
        super
        o.send(:jsi_schema_initialize)
      end

      # An application-wide default metaschema set by {default_metaschema=}, used by {JSI.new_schema}
      # to instantiate schemas which do not specify their metaschema using a `$schema` property.
      #
      # @return [nil, Base + Schema + Schema::DescribesSchema]
      def default_metaschema
        @default_metaschema
      end

      # Sets {default_metaschema} to a schema indicated by the given param.
      #
      # @param default_metaschema [Schema::DescribesSchema, SchemaModule::DescribesSchemaModule, #to_str, nil]
      #   Indicates the default metaschema.
      #   This may be a metaschema or a metaschema's schema module (e.g. `JSI::JSONSchemaOrgDraft07`),
      #   or a URI (as would be in a `$schema` keyword).
      #
      #   `nil` to unset.
      def default_metaschema=(default_metaschema)
        @default_metaschema = default_metaschema.nil? ? nil : ensure_describes_schema(default_metaschema)
      end

      # Instantiates the given schema content as a JSI Schema.
      #
      # The metaschema which describes the schema must be indicated:
      #
      # - if the schema object has a `$schema` property, that URI is resolved using the {JSI.schema_registry},
      #   and that metaschema is used.
      # - if no `$schema` property is present, the `default_metaschema` param is used, if the caller
      #   specifies it.
      # - if no `default_metaschema` param is specified, the application-wide default
      #   {JSI::Schema.default_metaschema JSI::Schema.default_metaschema} is used,
      #   if the application has set it.
      #
      # an ArgumentError is raised if none of these indicate a metaschema to use.
      #
      # Note that if you are instantiating a schema known to have no `$schema` property, an alternative to
      # specifying a `default_metaschema` is to call `new_schema` on the metaschema or its module
      # ({Schema::DescribesSchema#new_schema} / {SchemaModule::DescribesSchemaModule#new_schema}), e.g.
      # `JSI::JSONSchemaOrgDraft07.new_schema(my_schema_content)`
      #
      # @param schema_content (see Schema::DescribesSchema#new_schema)
      # @param default_metaschema [Schema::DescribesSchema, SchemaModule::DescribesSchemaModule, #to_str]
      #   Indicates the metaschema to use if the given schema_content does not have a `$schema` property.
      #   This may be a metaschema or a metaschema's schema module (e.g. `JSI::JSONSchemaOrgDraft07`),
      #   or a URI (as would be in a `$schema` keyword).
      # @param uri (see Schema::DescribesSchema#new_schema)
      # @param stringify_symbol_keys (see Schema::DescribesSchema#new_schema)
      # @return [JSI::Base subclass + JSI::Schema] a JSI which is a {JSI::Schema} whose content comes from
      #   the given `schema_content` and whose schemas are inplace applicators of the indicated metaschema
      def new_schema(schema_content,
          default_metaschema: nil,
          # params of DescribesSchema#new_schema have their default values repeated here. delegating in a splat
          # would remove repetition, but yard doesn't display delegated defaults with its (see X) directive.
          uri: nil,
          stringify_symbol_keys: true
      )
        new_schema_params = {
          uri: uri,
          stringify_symbol_keys: stringify_symbol_keys,
        }
        default_metaschema_new_schema = -> {
          default_metaschema = if default_metaschema
            ensure_describes_schema(default_metaschema, name: "default_metaschema")
          elsif Schema.default_metaschema
            Schema.default_metaschema
          else
            raise(ArgumentError, [
              "When instantiating a schema with no `$schema` property, you must specify its metaschema by one of these methods:",
              "- pass the `default_metaschema` param to this method",
              "  e.g.: JSI.new_schema(..., default_metaschema: JSI::JSONSchemaOrgDraft07)",
              "- invoke `new_schema` on the appropriate metaschema or its schema module",
              "  e.g.: JSI::JSONSchemaOrgDraft07.new_schema(...)",
              "- set JSI::Schema.default_metaschema to an application-wide default metaschema initially",
              "  e.g.: JSI::Schema.default_metaschema = JSI::JSONSchemaOrgDraft07",
              "instantiating schema_content: #{schema_content.pretty_inspect.chomp}",
            ].join("\n"))
          end
          default_metaschema.new_schema(schema_content, **new_schema_params)
        }
        if schema_content.is_a?(Schema)
          raise(TypeError, [
            "Given schema_content is already a JSI::Schema. It cannot be instantiated as the content of a schema.",
            "given: #{schema_content.pretty_inspect.chomp}",
          ].join("\n"))
        elsif schema_content.is_a?(JSI::Base)
          raise(TypeError, [
            "Given schema_content is a JSI::Base. It cannot be instantiated as the content of a schema.",
            "given: #{schema_content.pretty_inspect.chomp}",
          ].join("\n"))
        elsif schema_content.respond_to?(:to_hash)
          id = schema_content['$schema'] || stringify_symbol_keys && schema_content[:'$schema']
          if id
            unless id.respond_to?(:to_str)
              raise(ArgumentError, "given schema_content keyword `$schema` is not a string")
            end
            metaschema = Schema::Ref.new(id).deref_schema
            unless metaschema.describes_schema?
              raise(TypeError, "given schema_content contains a $schema but the resource it identifies does not describe a schema")
            end
            metaschema.new_schema(schema_content, **new_schema_params)
          else
            default_metaschema_new_schema.call
          end
        elsif [true, false].include?(schema_content)
          default_metaschema_new_schema.call
        else
          raise(TypeError, "cannot instantiate Schema from: #{schema_content.pretty_inspect.chomp}")
        end
      end

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
          if reinstantiate_as && schema.is_a?(JSI::Base)
            # TODO warn; behavior is undefined and I hate this implementation

            result_schema_schemas = schema.jsi_schemas + reinstantiate_as

            result_schema_class = JSI::SchemaClasses.class_for_schemas(result_schema_schemas,
              includes: SchemaClasses.includes_for(schema.jsi_node_content)
            )

            result_schema_class.new(schema.jsi_document,
              jsi_ptr: schema.jsi_ptr,
              jsi_root_node: schema.jsi_ptr.root? ? nil : schema.jsi_root_node, # bad
              jsi_indicated_schemas: schema.jsi_indicated_schemas,
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

      # Ensures the given param identifies a JSI Schema which describes schemas, and returns that schema.
      #
      # @api private
      # @param describes_schema [Schema::DescribesSchema, SchemaModule::DescribesSchemaModule, #to_str]
      # @raise [TypeError] if the param does not indicate a schema which describes schemas
      # @return [Base + Schema + Schema::DescribesSchema]
      def ensure_describes_schema(describes_schema, name: nil)
        if describes_schema.respond_to?(:to_str)
          schema = Schema::Ref.new(describes_schema).deref_schema
          if !schema.describes_schema?
            raise(TypeError, [name, "URI indicates a schema which does not describe schemas: #{describes_schema.pretty_inspect.chomp}"].compact.join(" "))
          end
          schema
        elsif describes_schema.is_a?(SchemaModule::DescribesSchemaModule)
          describes_schema.schema
        elsif describes_schema.is_a?(DescribesSchema)
          describes_schema
        else
          raise(TypeError, "#{name || "param"} does not indicate a schema which describes schemas: #{describes_schema.pretty_inspect.chomp}")
        end
      end
    end

    self.default_metaschema = nil

    if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
      def initialize(*)
        super
        jsi_schema_initialize
      end
    else
      def initialize(*, **)
        super
        jsi_schema_initialize
      end
    end

    # the underlying JSON data used to instantiate this JSI::Schema.
    # this is an alias for {Base#jsi_node_content}, named for clarity in the context of working with
    # a schema.
    def schema_content
      jsi_node_content
    end

    # does this schema contain the given keyword?
    # @return [Boolean]
    def keyword?(keyword)
      schema_content = jsi_node_content
      schema_content.respond_to?(:to_hash) && schema_content.key?(keyword)
    end

    # the URI of this schema, calculated from our `#id`, resolved against our `#jsi_schema_base_uri`
    # @return [Addressable::URI, nil]
    def schema_absolute_uri
      if respond_to?(:id_without_fragment) && id_without_fragment
        if jsi_schema_base_uri
          jsi_schema_base_uri.join(id_without_fragment).freeze
        elsif id_without_fragment.absolute?
          id_without_fragment
        else
          # TODO warn / schema_error
          nil
        end
      end
    end

    # a nonrelative URI which refers to this schema.
    # nil if no parent of this schema defines an id.
    # see {#schema_uris} for all URIs known to refer to this schema.
    # @return [Addressable::URI, nil]
    def schema_uri
      schema_uris.first
    end

    # nonrelative URIs (that is, absolute, but possibly with a fragment) which refer to this schema
    # @return [Array<Addressable::URI>]
    def schema_uris
      jsi_memoize(:schema_uris) do
        each_schema_uri.to_a
      end
    end

    # see {#schema_uris}
    # @yield [Addressable::URI]
    # @return [Enumerator, nil]
    def each_schema_uri
      return to_enum(__method__) unless block_given?

      yield schema_absolute_uri if schema_absolute_uri

      parent_schemas = jsi_subschema_resource_ancestors.reverse_each.select do |resource|
        resource.schema_absolute_uri
      end

      anchored = respond_to?(:anchor) ? anchor : nil
      parent_schemas.each do |parent_schema|
        if anchored
          if parent_schema.jsi_anchor_subschema(anchor) == self
            yield parent_schema.schema_absolute_uri.merge(fragment: anchor).freeze
          else
            anchored = false
          end
        end

        relative_ptr = jsi_ptr.relative_to(parent_schema.jsi_ptr)
        yield parent_schema.schema_absolute_uri.merge(fragment: relative_ptr.fragment).freeze
      end

      nil
    end

    # a module which extends all instances of this schema. this may be opened by the application to add
    # methods to schema instances.
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
    # @return [Module + SchemaModule]
    def jsi_schema_module
      JSI::SchemaClasses.module_for_schema(self)
    end

    # Evaluates the given block in the context of this schema's JSI schema module.
    # Any arguments passed to this method will be passed to the block.
    # shortcut to invoke [Module#module_exec](https://ruby-doc.org/core/Module.html#method-i-module_exec)
    # on our {#jsi_schema_module}.
    #
    # @return the result of evaluating the block
    def jsi_schema_module_exec(*a, **kw, &block)
      jsi_schema_module.module_exec(*a, **kw, &block)
    end

    # Instantiates a new JSI whose content comes from the given `instance` param.
    # This schema indicates the schemas of the JSI - its schemas are inplace
    # applicators of this schema which apply to the given instance.
    #
    # @param (see SchemaSet#new_jsi)
    # @return [JSI::Base subclass] a JSI whose content comes from the given instance and whose schemas are
    #   inplace applicators of this schema.
    def new_jsi(instance, **kw)
      SchemaSet[self].new_jsi(instance, **kw)
    end

    # does this schema itself describe a schema?
    # @return [Boolean]
    def describes_schema?
      jsi_schema_module <= JSI::Schema
    end

    # indicates that this schema describes a schema.
    # this schema is extended with {DescribesSchema} and its {#jsi_schema_module} is extended
    # with {SchemaModule::DescribesSchemaModule}, and the JSI Schema Module will include
    # JSI::Schema and the given modules.
    #
    # @param schema_implementation_modules [Enumerable<Module>] modules which implement the functionality of
    #   the schema to extend schemas described by this schema.
    # @return [void]
    def describes_schema!(schema_implementation_modules, objectspace: false)
      schema_implementation_modules = Util.ensure_module_set(schema_implementation_modules)

      if describes_schema?
        # this schema, or one equal to it, has already had describes_schema! called on it.
        # this is to be avoided, but is not particularly a problem.
        # it is a bug if it was called different times with different schema_implementation_modules, though.
        unless jsi_schema_module.schema_implementation_modules == schema_implementation_modules
          raise(ArgumentError, "this schema already describes a schema with different schema_implementation_modules")
        end
      else
        jsi_schema_module.include(Schema)
        schema_implementation_modules.each do |mod|
          jsi_schema_module.include(mod)
        end
        if objectspace
          ObjectSpace.each_object(jsi_schema_module) do |schema|
            schema.extend(Schema)
            schema_implementation_modules.each do |mod|
              schema.extend(mod)
            end
          end
        end
        jsi_schema_module.extend(SchemaModule::DescribesSchemaModule)
        jsi_schema_module.instance_variable_set(:@schema_implementation_modules, schema_implementation_modules)
      end

      extend(DescribesSchema)

      nil
    end

    # a resource containing this schema.
    #
    # if any parent, or this schema itself, is a schema with an absolute uri (see {#schema_absolute_uri}),
    # the resource root is the closest schema with an absolute uri.
    #
    # if no parent schema has an absolute uri, the schema_resource_root is the root of the document
    # (our #jsi_root_node). in this case, the resource root may or may not be a schema itself.
    #
    # @return [JSI::Base] resource containing this schema
    def schema_resource_root
      jsi_subschema_resource_ancestors.reverse_each.detect(&:schema_resource_root?) || jsi_root_node
    end

    # is this schema the root of a schema resource?
    # @return [Boolean]
    def schema_resource_root?
      jsi_ptr.root? || !!schema_absolute_uri
    end

    # a subschema of this Schema
    #
    # @param subptr [JSI::Ptr, #to_ary] a relative pointer, or array of tokens, pointing to the subschema
    # @return [JSI::Schema] the subschema at the location indicated by subptr. self if subptr is empty.
    def subschema(subptr)
      subschema_map[subptr: Ptr.ary_ptr(subptr)]
    end

    private

    def subschema_map
      jsi_memomap(:subschema) do |subptr: |
        if is_a?(MetaschemaNode::BootstrapSchema)
          self.class.new(
            jsi_document,
            jsi_ptr: jsi_ptr + subptr,
            jsi_schema_base_uri: jsi_resource_ancestor_uri,
          )
        else
          Schema.ensure_schema(jsi_descendent_node(subptr), msg: [
            "subschema is not a schema at pointer: #{subptr.pointer}"
          ])
        end
      end
    end

    public

    # a schema in the same schema resource as this one (see {#schema_resource_root}) at the given
    # pointer relative to the root of the schema resource.
    #
    # @param ptr [JSI::Ptr, #to_ary] a pointer to a schema from our schema resource root
    # @return [JSI::Schema] the schema pointed to by ptr
    def resource_root_subschema(ptr)
      resource_root_subschema_map[ptr: Ptr.ary_ptr(ptr)]
    end

    private

    def resource_root_subschema_map
      jsi_memomap(:resource_root_subschema_map) do |ptr: |
        if is_a?(MetaschemaNode::BootstrapSchema)
          # BootstrapSchema does not track jsi_schema_resource_ancestors used by #schema_resource_root;
          # resource_root_subschema is always relative to the document root.
          # BootstrapSchema also does not implement jsi_root_node or #[]. we instantiate the ptr directly
          # rather than as a subschema from the root.
          self.class.new(
            jsi_document,
            jsi_ptr: ptr,
            jsi_schema_base_uri: nil,
          )
        else
          Schema.ensure_schema(schema_resource_root.jsi_descendent_node(ptr),
            msg: [
              "subschema is not a schema at pointer: #{ptr.pointer}"
            ],
            reinstantiate_as: jsi_schemas.select(&:describes_schema?)
          )
        end
      end
    end

    public

    # any object property names this schema indicates may be present on its instances.
    # this includes any keys of this schema's "properties" object and any entries of this schema's
    # array of "required" property keys.
    # @return [Set]
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
      if instance.is_a?(Base)
        instance_ptr = instance.jsi_ptr
        instance_document = instance.jsi_document
      else
        instance_ptr = Ptr[]
        instance_document = instance
      end
      internal_validate_instance(instance_ptr, instance_document)
    end

    # whether the given instance is valid against this schema
    # @param instance [Object] the instance to validate against this schema
    # @return [Boolean]
    def instance_valid?(instance)
      if instance.is_a?(Base)
        instance = instance.jsi_node_content
      end
      internal_validate_instance(Ptr[], instance, validate_only: true).valid?
    end

    # schema resources which are ancestors of any subschemas below this schema.
    # this may include this schema if this is a schema resource root.
    # @api private
    # @return [Array<JSI::Schema>]
    def jsi_subschema_resource_ancestors
      if schema_resource_root?
        jsi_schema_resource_ancestors.dup.push(self).freeze
      else
        jsi_schema_resource_ancestors
      end
    end

    private

    def jsi_schema_initialize
    end
  end
end
