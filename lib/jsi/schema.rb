# frozen_string_literal: true

module JSI
  # JSI::Schema is a module which extends {JSI::Base} instances which represent JSON schemas.
  #
  # This module is included on the {Schema#jsi_schema_module JSI Schema module} of any schema
  # that describes other schemas, i.e. is a meta-schema (a {Schema::MetaSchema}).
  # Therefore, any JSI instance described by a schema which is a {Schema::MetaSchema} is
  # a schema and is extended by this module.
  #
  # The content of an instance which is a JSI::Schema (referred to in this context as schema_content) is
  # typically a Hash (JSON object) or a boolean.
  module Schema
    autoload(:Element, 'jsi/schema/element')
    autoload(:Vocabulary, 'jsi/schema/vocabulary')
    autoload(:Dialect, 'jsi/schema/dialect')
    autoload(:Cxt, 'jsi/schema/cxt')

    autoload(:Elements, 'jsi/schema/elements')

    autoload :Issue, 'jsi/schema/issue'
    autoload :Ref, 'jsi/schema/ref'
    autoload(:DynamicAnchorMap, 'jsi/schema/dynamic_anchor_map')

    autoload :SchemaAncestorNode, 'jsi/schema/schema_ancestor_node'

    autoload :Draft04, 'jsi/schema/draft04'
    autoload :Draft06, 'jsi/schema/draft06'
    autoload :Draft07, 'jsi/schema/draft07'

    class Error < StandardError
    end

    # an exception raised when a thing is expected to be a JSI::Schema, but is not
    class NotASchemaError < Error
    end

    class NotAMetaSchemaError < TypeError
    end

    # @deprecated alias after v0.8
    # an exception raised when we are unable to resolve a schema reference
    ReferenceError = ResolutionError

    # This module extends any JSI Schema that is a meta-schema, i.e. it describes schemas.
    #
    # Examples of a meta-schema include the JSON Schema meta-schemas and
    # the OpenAPI schema definition which describes "A deterministic version of a JSON Schema object."
    #
    # Meta-schemas include {JSI::Schema} in their
    # {Schema#jsi_schema_module JSI Schema module}, so for a schema which is an instance of
    # JSI::Schema::MetaSchema, instances of that schema are instances of {JSI::Schema} and are schemas.
    #
    # A schema is indicated as describing other schemas using the {Schema#describes_schema!} method.
    module MetaSchema
      # @return [Schema::Dialect]
      attr_reader(:described_dialect)

      # Instantiates the given schema content as a JSI Schema.
      #
      # By default, the schema will be registered with the {JSI.schema_registry}.
      # This can be controlled by params `register` and `schema_registry`.
      #
      # By default, the `schema_content` will have any Symbol keys of Hashes replaced with Strings
      # (recursively through the document). This is controlled by the param `stringify_symbol_keys`.
      #
      # Schemas instantiated with `new_schema` are immutable, their content transformed using
      # the `to_immutable` param.
      #
      # @param schema_content an object to be instantiated as a JSI Schema - typically a Hash
      # @param uri [#to_str, URI] The retrieval URI of the schema document.
      #   If specified, the root schema will be identified by this URI, in addition
      #   to any absolute URI declared with an id keyword, for resolution in the `schema_registry`.
      #
      #   It is rare that this needs to be specified. Most schemas, if they use absolute URIs, will
      #   use the `$id` keyword (`id` in draft 4) to specify this. A different retrieval URI is useful
      #   in unusual cases:
      #
      #     - A schema in the document uses relative URIs for `$id` or `$ref` without an absolute id in an
      #       ancestor schema - these will be resolved relative to this URI
      #     - Another schema refers with `$ref` to the schema being instantiated by this retrieval URI,
      #       rather than an id declared in the schema - the schema is resolvable by this URI in the
      #       `schema_registry`.
      # @param register [Boolean] Whether the instantiated schema and any subschemas with absolute URIs
      #   will be registered in the schema registry indicated by param `schema_registry`.
      # @param schema_registry [SchemaRegistry, nil] The registry this schema will use.
      #
      #   - The schema and subschemas will be registered here with any declared URI,
      #     unless the `register` param is false.
      #   - References from within the schema (typically from `$ref` keywords) are resolved using this registry.
      # @param stringify_symbol_keys [Boolean] Whether the schema content will have any Symbol keys of Hashes
      #   replaced with Strings (recursively through the document).
      #   Replacement is done on a copy; the given schema content is not modified.
      # @param to_immutable (see SchemaSet#new_jsi)
      # @yield If a block is given, it is evaluated in the context of the schema's JSI schema module
      #   using [Module#module_exec](https://ruby-doc.org/core/Module.html#method-i-module_exec).
      # @return [JSI::Base subclass + JSI::Schema] a JSI which is a {JSI::Schema} whose content comes from
      #   the given `schema_content` and whose schemas are this meta-schema's in-place applicators.
      def new_schema(schema_content,
          uri: nil,
          register: true,
          schema_registry: JSI.schema_registry,
          stringify_symbol_keys: true,
          to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
          &block
      )
        schema_jsi = new_jsi(schema_content,
          uri: uri,
          register: register,
          schema_registry: schema_registry,
          stringify_symbol_keys: stringify_symbol_keys,
          to_immutable: to_immutable,
          mutable: false,
        )

        schema_jsi.jsi_schema_module_exec(&block) if block

        schema_jsi
      end

      # Instantiates the given schema content as a JSI Schema, passing all params to
      # {Schema::MetaSchema#new_schema}, and returns its {Schema#jsi_schema_module JSI Schema Module}.
      #
      # @return [JSI::SchemaModule] the JSI Schema Module of the instantiated schema
      def new_schema_module(schema_content, **kw, &block)
        new_schema(schema_content, **kw, &block).jsi_schema_module
      end
    end

    # @private
    module ExtendedInitialize
      def extended(o)
        super
        o.send(:jsi_schema_initialize)
      end

      def included(m)
        super
        return if m.is_a?(Class)

        # if a module (m) includes Schema, and an object (o) is extended with m,
        # then o should have #jsi_schema_initialize called, but Schema.extended is not called,
        # so m needs its own .extended method to call jsi_schema_initialize.
        # note: including a module with #extended on m's singleton, rather than m.define_singleton_method(:extended),
        # avoids possibly clobbering an existing singleton .extended method the module has defined.
        m.singleton_class.send(:include, ExtendedInitialize)
      end
    end

    extend(ExtendedInitialize)
  end

  class << self
      # An application-wide default meta-schema set by {default_metaschema=}, used by {JSI.new_schema}
      # to instantiate schemas that do not specify their meta-schema using a `$schema` property.
      #
      # @return [nil, Base + Schema + Schema::MetaSchema]
      def default_metaschema
        @default_metaschema
      end

      # Sets {default_metaschema} to a schema indicated by the given param.
      #
      # @param default_metaschema [Schema::MetaSchema, SchemaModule::MetaSchemaModule, #to_str, nil]
      #   Indicates the default meta-schema.
      #   This may be a meta-schema or a meta-schema's schema module (e.g. `JSI::JSONSchemaDraft07`),
      #   or a URI (as would be in a `$schema` keyword).
      #
      #   `nil` to unset.
      def default_metaschema=(default_metaschema)
        @default_metaschema = default_metaschema.nil? ? nil : ensure_metaschema(default_metaschema)
      end

      # Instantiates the given schema content as a JSI Schema.
      #
      # The meta-schema that describes the schema must be indicated:
      #
      # - If the schema object has a `$schema` property, that URI is resolved using the `schema_registry`
      #   param (by default {JSI.schema_registry}), and that meta-schema is used. For example:
      #
      #   ```ruby
      #   JSI.new_schema({
      #     "$schema" => "http://json-schema.org/draft-07/schema#",
      #     "properties" => ...,
      #   })
      #   ```
      #
      # - if no `$schema` property is present, the `default_metaschema` param is used, if the caller
      #   specifies it. For example:
      #
      #   ```ruby
      #   JSI.new_schema({"properties" => ...}, default_metaschema: JSI::JSONSchemaDraft07)
      #   ```
      #
      # - if no `default_metaschema` param is specified, the application-wide default
      #   {JSI.default_metaschema JSI.default_metaschema} is used,
      #   if the application has set it. For example:
      #
      #   ```ruby
      #   JSI.default_metaschema = JSI::JSONSchemaDraft07
      #   JSI.new_schema({"properties" => ...})
      #   ```
      #
      # An ArgumentError is raised if none of these indicates a meta-schema to use.
      #
      # Note that if you are instantiating a schema known to have no `$schema` property, an alternative to
      # specifying a `default_metaschema` is to call `new_schema` on the
      # {Schema::MetaSchema#new_schema meta-schema} or its
      # {SchemaModule::MetaSchemaModule#new_schema schema module}, e.g.
      # `JSI::JSONSchemaDraft07.new_schema(my_schema_content)`
      #
      # Schemas instantiated with `new_schema` are immutable, their content transformed using
      # the `to_immutable` param.
      #
      # @param schema_content (see Schema::MetaSchema#new_schema)
      # @param default_metaschema [Schema::MetaSchema, SchemaModule::MetaSchemaModule, #to_str]
      #   Indicates the meta-schema to use if the given `schema_content` does not have a `$schema` property.
      #   This may be a meta-schema or a meta-schema's schema module (e.g. `JSI::JSONSchemaDraft07`),
      #   or a URI (as would be in a `$schema` keyword).
      # @param uri (see Schema::MetaSchema#new_schema)
      # @param register (see Schema::MetaSchema#new_schema)
      # @param schema_registry (see Schema::MetaSchema#new_schema)
      # @param stringify_symbol_keys (see Schema::MetaSchema#new_schema)
      # @param to_immutable (see Schema::DescribesSchema#new_schema)
      # @yield (see Schema::MetaSchema#new_schema)
      # @return [JSI::Base subclass + JSI::Schema] a JSI which is a {JSI::Schema} whose content comes from
      #   the given `schema_content` and whose schemas are in-place applicators of the indicated meta-schema.
      def new_schema(schema_content,
          default_metaschema: nil,
          # params of Schema::MetaSchema#new_schema have their default values repeated here. delegating in a splat
          # would remove repetition, but yard doesn't display delegated defaults with its (see X) directive.
          uri: nil,
          register: true,
          schema_registry: JSI.schema_registry,
          stringify_symbol_keys: true,
          to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
          &block
      )
        new_schema_params = {
          uri: uri,
          register: register,
          schema_registry: schema_registry,
          stringify_symbol_keys: stringify_symbol_keys,
          to_immutable: to_immutable,
        }
        default_metaschema_new_schema = -> {
          default_metaschema = if default_metaschema
            Schema.ensure_metaschema(default_metaschema, name: "default_metaschema", schema_registry: schema_registry)
          elsif self.default_metaschema
            self.default_metaschema
          else
            raise(ArgumentError, [
              "When instantiating a schema with no `$schema` property, you must specify its meta-schema by one of these methods:",
              "- pass the `default_metaschema` param to this method",
              "  e.g.: JSI.new_schema(..., default_metaschema: JSI::JSONSchemaDraft07)",
              "- invoke `new_schema` on the appropriate meta-schema or its schema module",
              "  e.g.: JSI::JSONSchemaDraft07.new_schema(...)",
              "- set JSI.default_metaschema to an application-wide default meta-schema initially",
              "  e.g.: JSI.default_metaschema = JSI::JSONSchemaDraft07",
              "instantiating schema_content: #{schema_content.pretty_inspect.chomp}",
            ].join("\n"))
          end
          default_metaschema.new_schema(schema_content, **new_schema_params, &block)
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
            metaschema = Schema.ensure_metaschema(id, name: '$schema', schema_registry: schema_registry)
            metaschema.new_schema(schema_content, **new_schema_params, &block)
          else
            default_metaschema_new_schema.call
          end
        else
          default_metaschema_new_schema.call
        end
      end
  end

  self.default_metaschema = nil

  module Schema
    class << self
      # ensure the given object is a JSI Schema
      #
      # @param schema [Object] the thing the caller wishes to ensure is a Schema
      # @yieldreturn [#to_s, #to_ary] first line(s) of the error message, overriding the default
      # @raise [NotASchemaError] if the schema param is not a schema
      # @return [Schema] the given schema
      def ensure_schema(schema, reinstantiate_as: nil)
        if schema.is_a?(Schema)
          schema
        else
          if reinstantiate_as && schema.is_a?(JSI::Base)
            # TODO warn; behavior is undefined and I hate this implementation

            result_schema_indicated_schemas = SchemaSet.new(schema.jsi_indicated_schemas + reinstantiate_as)
            result_schema_applied_schemas = result_schema_indicated_schemas.each_yield_set do |is, y|
              is.each_inplace_applicator_schema(schema.jsi_node_content, &y)
            end

            result_schema_class = JSI::SchemaClasses.class_for_schemas(result_schema_applied_schemas,
              includes: SchemaClasses.includes_for(schema.jsi_node_content),
              mutable: schema.jsi_mutable?,
            )

            result_schema_class.new(schema.jsi_document,
              jsi_ptr: schema.jsi_ptr,
              jsi_indicated_schemas: result_schema_indicated_schemas,
              jsi_schema_base_uri: schema.jsi_schema_base_uri,
              jsi_schema_resource_ancestors: schema.jsi_schema_resource_ancestors,
              jsi_schema_dynamic_anchor_map: schema.jsi_schema_dynamic_anchor_map,
              jsi_schema_registry: schema.jsi_schema_registry,
              jsi_content_to_immutable: schema.jsi_content_to_immutable,
              jsi_root_node: schema.equal?(schema.jsi_root_node) ? nil : schema.jsi_root_node, # bad
            )
          else
            msg = []
            msg.concat([*(block_given? ? yield : "indicated object is not a schema:")])
            msg << schema.pretty_inspect.chomp
            if schema.is_a?(Base)
              msg << "its schemas (which should include a Meta-Schema): #{schema.jsi_schemas.pretty_inspect.chomp}"
            end
            raise(NotASchemaError, msg.compact.join("\n"))
          end
        end
      end

      # Ensures the given param identifies a meta-schema and returns that meta-schema.
      #
      # @api private
      # @param metaschema [Schema::MetaSchema, SchemaModule::MetaSchemaModule, #to_str]
      # @raise [TypeError] if the param does not indicate a meta-schema
      # @return [Base + Schema + Schema::MetaSchema]
      def ensure_metaschema(metaschema, name: nil, schema_registry: JSI.schema_registry)
        if metaschema.respond_to?(:to_str)
          schema = Schema::Ref.new(metaschema, schema_registry: schema_registry).deref_schema
          if !schema.describes_schema?
            raise(NotAMetaSchemaError, [name, "URI indicates a schema that is not a meta-schema: #{metaschema.pretty_inspect.chomp}"].compact.join(" "))
          end
          schema
        elsif metaschema.is_a?(SchemaModule::MetaSchemaModule)
          metaschema.schema
        elsif metaschema.is_a?(Schema::MetaSchema)
          metaschema
        else
          raise(NotAMetaSchemaError, "#{name || "param"} does not indicate a meta-schema: #{metaschema.pretty_inspect.chomp}")
        end
      end
    end

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

    # Does this schema contain the given keyword with the given value?
    # @return [Boolean]
    def keyword_value?(keyword, value)
      keyword?(keyword) && schema_content[keyword] == value
    end

    # the string contents of an `$id`/`id` keyword, or nil
    # @return [#to_str, nil]
    def id
      dialect_invoke_each(:id).first
    end

    # @return [Enumerable<String>]
    def anchors
      anchors = Set[]
      anchors.merge(dialect_invoke_each(:anchor))
      anchors.merge(dialect_invoke_each(:dynamicAnchor))
      anchors.freeze
    end

    # the URI of this schema, calculated from our `#id`, resolved against our `#jsi_schema_base_uri`
    # @return [URI, nil]
    def schema_absolute_uri
      schema_absolute_uris.first
    end

    # @return [Enumerable<URI>]
    def schema_absolute_uris
      @schema_absolute_uris_map[schema_content: schema_content]
    end

    # @yield [URI]
    private def schema_absolute_uris_compute
      root_uri = jsi_schema_base_uri if jsi_ptr.root?
      dialect_invoke_each(:id_without_fragment) do |id_without_fragment|
        if jsi_schema_base_uri
          uri = jsi_schema_base_uri.join(id_without_fragment)
          root_uri = nil if root_uri == uri
          yield(uri)
        elsif id_without_fragment.absolute?
          yield(id_without_fragment)
        end
      end
      yield(root_uri) if root_uri
    end

    # a nonrelative URI which refers to this schema.
    # `nil` if no ancestor of this schema defines an id.
    # see {#schema_uris} for all URIs known to refer to this schema.
    # @return [URI, nil]
    def schema_uri
      schema_uris.first
    end

    # nonrelative URIs (that is, absolute, but possibly with a fragment) which refer to this schema
    # @return [Array<URI>]
    def schema_uris
      @schema_uris_map[schema_content: schema_content]
    end

    # @yield [URI]
    private def schema_uris_compute(&block)
      schema_absolute_uris.each(&block)

      if schema_resource_root
        anchors.each do |anchor|
          schema_resource_root.schema_absolute_uris.each do |uri|
            yield(uri.merge(fragment: anchor))
          end
        end
      end

      jsi_subschema_resource_ancestors.reverse_each do |ancestor_schema|
        relative_ptr = jsi_ptr.relative_to(ancestor_schema.jsi_ptr)
        ancestor_schema.schema_absolute_uris.each do |uri|
          yield(uri.merge(fragment: relative_ptr.fragment))
        end
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
    # @return [SchemaModule]
    def jsi_schema_module
      raise(TypeError, "non-Base schema may not have a schema module: #{self}") unless is_a?(Base)
      raise(TypeError, "mutable schema may not have a schema module: #{self}") if jsi_mutable?
      @jsi_schema_module ||= SchemaModule.new(self)
    end

    # @private
    # @return [Boolean]
    def jsi_schema_module_defined?
      !!@jsi_schema_module
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

    # @return [String, nil]
    def jsi_schema_module_name
      @jsi_schema_module && @jsi_schema_module.name
    end

    # @return [String, nil]
    def jsi_schema_module_name_from_ancestor
      is_a?(Base) ? jsi_schema_module.name_from_ancestor : nil
    end

    # Instantiates a new JSI whose content comes from the given `instance` param.
    # This schema indicates the schemas of the JSI - its schemas are in-place
    # applicators of this schema which apply to the given instance.
    #
    # @param (see SchemaSet#new_jsi)
    # @return [Base] a JSI whose content comes from the given instance and whose schemas are
    #   in-place applicators of this schema.
    def new_jsi(instance, **kw)
      SchemaSet[self].new_jsi(instance, **kw)
    end

    # @param keyword schema keyword e.g. "$ref", "$schema"
    # @return [Schema::Ref]
    # @raise [Base::ChildNotPresent]
    def schema_ref(keyword = "$ref")
      raise(Base::ChildNotPresent, "keyword not present: #{keyword}") unless keyword?(keyword)
      @schema_ref_map[keyword: keyword, value: schema_content[keyword]]
    end

    # Does this schema itself describe a schema? I.e. is this schema a meta-schema?
    # @return [Boolean]
    def describes_schema?
      is_a?(Schema::MetaSchema)
    end

    # Is this a JSI Schema?
    # @return [Boolean]
    def jsi_is_schema?
      true
    end

    # Indicates that this schema describes schemas, i.e. it is a meta-schema.
    # this schema is extended with {Schema::MetaSchema} and its {#jsi_schema_module} is extended
    # with {SchemaModule::MetaSchemaModule}, and the JSI Schema Module will include
    # JSI::Schema.
    #
    # @param dialect [Schema::Dialect]
    # @return [void]
    def describes_schema!(dialect)
      # TODO rm bridge code hax
      dialect = dialect.first::DIALECT if dialect.is_a?(Array) && dialect.size == 1
      raise(TypeError) if !dialect.is_a?(Schema::Dialect)

      if jsi_schema_module <= Schema
        # this schema has already had describes_schema! called on it.
        # this is to be avoided, but is not particularly a problem.
        # it is a bug if it was called different times with different dialect, though.
        if @described_dialect != dialect
          raise(ArgumentError, "this schema already describes a schema with different dialect")
        end
      else
        jsi_schema_module.include(Schema)
        jsi_schema_module.send(:define_method, :dialect) { dialect }
        proc { |metaschema| jsi_schema_module.send(:define_method, :metaschema) { metaschema } }[self]
        jsi_schema_module.extend(SchemaModule::MetaSchemaModule)
      end

      @described_dialect = dialect
      extend(Schema::MetaSchema)

      nil
    end

    # a resource containing this schema.
    #
    # If any ancestor, or this schema itself, is a schema with an absolute uri (see {#schema_absolute_uri}),
    # the resource root is the closest schema with an absolute uri.
    #
    # If no ancestor schema has an absolute uri, the schema_resource_root is the {Base#jsi_root_node document's root node}.
    # In this case, the resource root may or may not be a schema itself.
    #
    # @return [JSI::Base] resource containing this schema
    def schema_resource_root
      jsi_subschema_resource_ancestors.last || jsi_root_node
    end

    # is this schema the root of a schema resource?
    # @return [Boolean]
    def schema_resource_root?
      jsi_ptr.root? || schema_absolute_uris.any?
    end

    # a subschema of this Schema
    #
    # @param subptr [JSI::Ptr, #to_ary] a relative pointer, or array of tokens, pointing to the subschema
    # @return [JSI::Schema] the subschema at the location indicated by subptr. self if subptr is empty.
    def subschema(subptr)
      Schema.ensure_schema(jsi_descendent_node(subptr)) { "subschema is not a schema at pointer: #{Ptr.ary_ptr(subptr).pointer}" }
    end

    # a schema in the same schema resource as this one (see {#schema_resource_root}) at the given
    # pointer relative to the root of the schema resource.
    #
    # @param ptr [JSI::Ptr, #to_ary] a pointer to a schema from our schema resource root
    # @return [JSI::Schema] the schema pointed to by ptr
    def resource_root_subschema(ptr)
          Schema.ensure_schema(schema_resource_root.jsi_descendent_node(ptr),
            reinstantiate_as: jsi_schemas.select(&:describes_schema?)
          )
    end

    # @yield [Schema]
    def jsi_each_descendent_schema(&block)
      return(to_enum(__method__)) unless block_given?

      yield(self)
      dialect_invoke_each(:subschema) { |ptr| subschema(ptr).jsi_each_descendent_schema(&block) }
    end

    # yields each descendent of this node (including itself) within the same resource that is a Schema
    # @yield [Schema]
    def jsi_each_descendent_schema_same_resource(&block)
      return(to_enum(__method__)) unless block_given?

      yield(self)
      dialect_invoke_each(:subschema) do |ptr|
        desc = subschema(ptr)
        if !desc.schema_resource_root?
          desc.jsi_each_descendent_schema_same_resource(&block)
        end
      end
    end

    # @yield [Ptr]
    def each_immediate_subschema_ptr
      return(to_enum(__method__)) unless block_given?

      dialect_invoke_each(:subschema) { |ptr| yield(Ptr.ary_ptr(ptr)) }
    end

    # Yields each in-place applicator schema which applies to the given instance.
    #
    # @param instance [Object] the instance to check any applicators against
    # @param visited_refs [Enumerable<JSI::Schema::Ref>]
    # @yield [JSI::Schema]
    # @return [nil]
    def each_inplace_applicator_schema(
        instance,
        visited_refs: Util::EMPTY_ARY,
        &block
    )
      dialect_invoke_each(:inplace_applicate,
        Cxt::InplaceApplication,
        instance: instance,
        visited_refs: visited_refs,
        collect_evaluated: false, # child application is not invoked so no evaluated children to collect
      ) do |schema, ref: nil, applicate: true|
        if schema.equal?(self) && !ref
          yield(self)
        elsif applicate
          schema.each_inplace_applicator_schema(
            instance,
            visited_refs: Util.add_visited_ref(visited_refs, ref),
            &block
          )
        end
      end
    end

    # yields each child applicator subschema (from properties, items, etc.) which applies to the child of
    # the given instance on the given token.
    #
    # @param token [Object] the array index or object property name for the child instance
    # @param instance [Object] the instance to check any child applicators against
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def each_child_applicator_schema(token, instance, &block)
      dialect_invoke_each(:child_applicate,
        Cxt::ChildApplication,
        instance: instance,
        token: token,
        collect_evaluated: false,
        evaluated: false,
        &block
      )
    end

    # For each in-place applicator schema that applies to the given instance, yields each child applicator
    # of that schema that applies to the child of the instance on the given token.
    #
    # This method handles collection of whether the child was evaluated by any applicator
    # when that evaluation is needed by either this schema or the caller (per param `collect_evaluated`).
    # This is relevant to schemas containing `unevaluatedProperties` or `unevaluatedItems`.
    #
    # @param token [Object] array index or hash/object property name
    # @param instance [Object]
    # @param collect_evaluated [Boolean] Does the caller need this method to collect successful child evaluation?
    #   Note: this method will still collect child evaluation if this schema needs it; this only needs to be
    #   passed true when called by an in-place applicator schema that needs it (i.e. contains `unevaluated*`).
    # @yield [Schema]
    # @return [Boolean] if `collect_evaluated` is true, whether the child was successfully evaluated
    #   by a child applicator schema. if `collect_evaluated` is false, undefined/void.
    def each_inplace_child_applicator_schema(
        token,
        instance,
        visited_refs: Util::EMPTY_ARY,
        collect_evaluated: false,
        &block
    )
      collect_evaluated ||= application_requires_evaluated
      inplace_child_evaluated = false
      applicate_self = false

      dialect_invoke_each(:inplace_applicate,
        Cxt::InplaceApplication,
        instance: instance,
        visited_refs: visited_refs,
        collect_evaluated: collect_evaluated,
      ) do |schema, ref: nil, applicate: true|
        if schema.equal?(self) && !ref
          applicate_self = true
        elsif applicate || (collect_evaluated && !inplace_child_evaluated)
          schema_evaluated = schema.each_inplace_child_applicator_schema(
            token,
            instance,
            visited_refs: Util.add_visited_ref(visited_refs, ref),
            collect_evaluated: collect_evaluated && !inplace_child_evaluated,
            # the `if` keyword needs to yield to here because it does affect `evaluated`,
            # but it does not apply itself/its applicators, so is not passed to our given block.
            &(applicate ? block : proc { })
          )
          inplace_child_evaluated ||= collect_evaluated && schema_evaluated && schema.instance_valid?(instance)
        end
      end

      if applicate_self
        child_application = dialect.invoke(:child_applicate, Cxt::ChildApplication.new(
          schema: self,
          token: token,
          instance: instance,
          collect_evaluated: collect_evaluated,
          evaluated: inplace_child_evaluated,
          block: block,
        ))

        child_application.evaluated
      else
        inplace_child_evaluated
      end
    end

    # any object property names this schema indicates may be present on its instances.
    # this includes any keys of this schema's "properties" object and any entries of this schema's
    # array of "required" property keys.
    # @return [Set]
    def described_object_property_names
      @described_object_property_names_map[schema_content: schema_content]
    end

    # Validates the given instance against this schema, returning a result with each validation error.
    #
    # @param instance [Object] the instance to validate against this schema
    # @return [JSI::Validation::Result::Full]
    def instance_validate(instance)
      if instance.is_a?(SchemaAncestorNode)
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
      if instance.is_a?(SchemaAncestorNode)
        instance = instance.jsi_node_content
      end
      internal_validate_instance(Ptr[], instance, validate_only: true).valid?
    end

    # validates the given instance against this schema
    #
    # @private
    # @param instance_ptr [JSI::Ptr] a pointer to the instance to validate against the schema, in the instance_document
    # @param instance_document [#to_hash, #to_ary, Object] document containing the instance instance_ptr pointer points to
    # @param validate_only [Boolean] whether to return a full schema validation result or a simple, validation-only result
    # @param visited_refs [Enumerable<JSI::Schema::Ref>]
    # @return [JSI::Validation::Result]
    def internal_validate_instance(
        instance_ptr,
        instance_document,
        visited_refs: Util::EMPTY_ARY,
        validate_only: false
    )
      if validate_only
        result = JSI::Validation::Result::Valid.new
      else
        result = JSI::Validation::Result::Full.new
      end
      result_builder = result.class::Builder.new(
        result: result,
        schema: self,
        instance_ptr: instance_ptr,
        instance_document: instance_document,
        validate_only: validate_only,
        visited_refs: visited_refs,
      )

      catch(:jsi_validation_result) do
        dialect.invoke(:validate, result_builder)

        result
      end.freeze
    end

    # @param action_name [Symbol]
    # @param cxt_class [Class]
    # @yield
    def dialect_invoke_each(
        action_name,
        cxt_class = Cxt::Block,
        **cxt_param,
        &block
    )
      return(to_enum(__method__, action_name, cxt_class, **cxt_param)) unless block_given?

      cxt = cxt_class.new(
        schema: self,
        block: block,
        **cxt_param,
      )
      dialect.invoke(action_name, cxt)

      nil
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

    # @private
    def jsi_next_schema_dynamic_anchor_map
      return(@next_schema_dynamic_anchor_map) if @next_schema_dynamic_anchor_map

      @next_schema_dynamic_anchor_map = jsi_schema_dynamic_anchor_map

      anchor_root = schema_resource_root.is_a?(Schema) ? schema_resource_root : self
      descendent_schemas = [[anchor_root, Util::EMPTY_ARY]]

      while !descendent_schemas.empty?
        descendent_schema, ptrs = *descendent_schemas.shift

        descendent_schema.dialect_invoke_each(:dynamicAnchor) do |anchor|
          next if @next_schema_dynamic_anchor_map.key?(anchor)
          @next_schema_dynamic_anchor_map = @next_schema_dynamic_anchor_map.merge({
            anchor => [anchor_root, ptrs].freeze,
          }).freeze
        end

        descendent_schema.each_immediate_subschema_ptr do |subptr|
          # we want a schema at subptr to
          # - check if it is a schema resource root
          # - check for $dynamicAnchor
          # can't use #subschema here (it would need to pass this method's result to instantiate the subschema);
          # a minimal bootstrap schema is used instead.
          descendent_subschema = dialect.bootstrap_schema_class.new(
            jsi_document,
            jsi_ptr: descendent_schema.jsi_ptr + subptr,
            # note: same as anchor_root.jsi_resource_ancestor_uri since we don't cross resource boundaries.
            jsi_schema_base_uri: descendent_schema.jsi_resource_ancestor_uri,
          )
          if !descendent_subschema.schema_resource_root?
            descendent_schemas.push([descendent_subschema, ptrs.dup.push(subptr).freeze])
          end
        end
      end

      @next_schema_dynamic_anchor_map
    end

    # Does application require collection of evaluated children?
    # (i.e. does the schema contain `unevaluatedItems` / `unevaluatedProperties`?)
    # @private
    # @return [Boolean]
    attr_reader(:application_requires_evaluated)

    private

    KEY_BY_NONE = proc { nil }

    def jsi_schema_initialize
      # guard against being called twice on MetaSchemaNode, first from extend(Schema) then extend(jsi_schema_module) that includes Schema.
      # both extends need to initialize for edge case of draft4's boolean schema that is not described by meta-schema.
      instance_variable_defined?(:@jsi_schema_initialized) ? return : (@jsi_schema_initialized = true)
      @jsi_schema_module = nil
      @schema_ref_map = jsi_memomap(key_by: proc { |i| i[:keyword] }) do |keyword: , value: |
        Schema::Ref.new(value, ref_schema: self)
      end
      @schema_absolute_uris_map = jsi_memomap(key_by: KEY_BY_NONE) { to_enum(:schema_absolute_uris_compute).to_a.freeze }
      @schema_uris_map = jsi_memomap(key_by: KEY_BY_NONE) { to_enum(:schema_uris_compute).to_a.freeze }
      @described_object_property_names_map = jsi_memomap(key_by: KEY_BY_NONE) do
        dialect_invoke_each(:described_object_property_names).to_set.freeze
      end
      if dialect.elements.any? { |e| e.invokes?(:dynamicAnchor) }
        @next_schema_dynamic_anchor_map = nil
      else
        @next_schema_dynamic_anchor_map = jsi_schema_dynamic_anchor_map
      end
      @application_requires_evaluated = dialect_invoke_each(:application_requires_evaluated).any?
    end
  end
end
