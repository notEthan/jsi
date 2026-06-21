# frozen_string_literal: true

module JSI
  conf_attrs = {
    root_indicated_schemas:                 {fingerprint: false},
    base_uri:                               {fingerprint: false},
    root_uri:                               {fingerprint: true },
    register:                               {fingerprint: false},
    registry:                               {fingerprint: true },
    application_collect_evaluated_validate: {fingerprint: false},
    reinstantiate_nonschemas:               {fingerprint: false},
    after_initialize:                       {fingerprint: false},
    child_as_jsi:                           {fingerprint: false},
    child_use_default:                      {fingerprint: false},
    jsi_in_content:                         {fingerprint: false},
    stringify_symbol_keys:                  {fingerprint: false},
    to_immutable:                           {fingerprint: false},
    mutable:                                {fingerprint: false},
  }.freeze
  Base::Conf = Struct::Frozen.subclass(*conf_attrs.keys)
  class Base::Conf end
  Base::Conf::ATTRS = conf_attrs

  # Configuration, shared across all nodes of a document. A JSI's {Base#jsi_conf}.
  #
  # Configuration parameters are set from `**conf_kw` params passed to {SchemaSet#new_jsi #new_jsi},
  # {Schema::MetaSchema#new_schema #new_schema} and related methods.
  #
  # @!attribute root_indicated_schemas
  #   See {Base#jsi_indicated_schemas}
  #   @return [SchemaSet]
  # @!attribute base_uri
  #   The base URI of the instance document. An absolute URI.
  #
  #   It is rare that this needs to be specified. It is useful when the instance contains schemas,
  #   and schemas in the document use relative URIs for `$id` or `$ref` without an absolute id
  #   in an ancestor schema - those URIs will be resolved relative to `base_uri`.
  #
  #   See also {Base::Conf conf} {Base::Conf#root_uri `root_uri`}. `base_uri` is not used to identify
  #   any resource, only to resolve relative URIs. `root_uri` does identify the root resource.
  #   @return [#to_str, URI, nil]
  # @!attribute root_uri
  #   A URI identifying the document root resource.
  #   References (e.g. a schema `$ref`) can resolve the resource with this URI.
  #
  #   It is rare that this needs to be specified. Most resources that would be
  #   referenced are schemas that use the `$id` keyword to specify their URI.
  #   However, there are cases when a resource may be referenced using a retrieval URI
  #   that does not match the resource's `$id`, and `root_uri` enables resolution.
  #   @return [URI, nil]
  # @!attribute register
  #   Whether schema resources in the instantiated JSI will be registered
  #   in the {Base::Conf configured} {Base::Conf#registry `registry`}.
  #   This is only useful when the JSI is a schema or contains schemas.
  #
  #   Default: `false`
  #
  #   Default overridden to `true` for {Base::Conf::Schema} / `new_schema`
  #   @return [Boolean]
  # @!attribute registry
  #   The registry from which references are resolved.
  #   For schemas (or documents containing schemas), this is mainly used with `$ref` values.
  #   It is unused in instances that do not contain schemas.
  #
  #   Default: {JSI.registry}
  #   @return [Registry, nil]
  # @!attribute application_collect_evaluated_validate
  #   Shall schema application perform validation when collecting child evaluation
  #   (for `unevaluatedProperties`, `unevaluatedItems`)?
  #
  #   A child should not be considered evaluated by a schema when it fails to validate[^1].
  #   This means that `unevaluatedItems` or `unevaluatedProperties` should
  #   only apply to a child if no other applicator schema validates the child.
  #   The computational cost of this validation is significant, however, and may be unacceptable for performance.
  #
  #   Set to `true`, child evaluation will perform validation, and `unevaluated*` will applicate
  #   correctly, at some cost in CPU time.
  #
  #   Set to `false`, a child will be considered evaluated when a child applicator schema applies to it,
  #   regardless of validity, which will result in an `unevaluated*` schema incorrectly failing to
  #   applicate when the child is not valid.
  #
  #   The default is false. It is expected that application of `unevaluated*` schemas to such children
  #   is not typically relied on, so validation is not typically worth the cost of its computation.
  #
  #   [^1]: (ref: the JSON Schema spec states, "Schema objects that produce a false assertion result MUST
  #   NOT produce any annotation results, whether from their own keywords or from keywords in subschemas.")
  #
  #   Default: false
  #   @return [Boolean]
  # @!attribute reinstantiate_nonschemas
  #   _private, not officially supported_. whether Schema#resource_root_subschema reinstantiates.
  # @!attribute after_initialize
  #   _EXPERIMENTAL_ - a callback that is called with each JSI node in the document after the node is initialized.
  #   @return [#call, nil]
  # @!attribute child_as_jsi
  #   Default value for {Base#jsi_child_as_jsi_default}.
  #   @return [true, false, :auto]
  # @!attribute child_use_default
  #   Default value for {Base#jsi_child_use_default_default}.
  #   @return [Boolean]
  # @!attribute jsi_in_content
  #   A JSI node's content shuld not contain another JSI instance. This controls how it is handled if that is encountered.
  #
  #   Default: `:raise`
  #   @return [:raise, :strip, :ignore]
  # @!attribute stringify_symbol_keys
  #   Whether the instance content will have any Symbol keys of Hashes
  #   replaced with Strings (recursively through the document).
  #   Replacement is done on a copy; the given instance is not modified.
  #
  #   Default: `false`
  #
  #   Default overridden to `true` for {Base::Conf::Schema} / `new_schema`
  #   @return [Boolean]
  # @!attribute to_immutable
  #   A callable that transforms given instance content to an immutable (i.e. deeply frozen) object equal to it.
  #
  #   Used when instantiating immutable JSIs and modified copies of them, so their content is immutable.
  #
  #   If the instantiated JSI will be mutable, this is not used.
  #
  #   Though not recommended, this may be nil with immutable JSIs if the instance content is otherwise
  #   guaranteed to be immutable, as well as any modified copies of the instance.
  #
  #   Default: {DEFAULT_CONTENT_TO_IMMUTABLE}
  #   @return [#call, nil]
  # @!attribute mutable
  #   Whether the instantiated JSI will be mutable.
  #   The instance content will be transformed with the {Base::Conf configured}
  #   {Base::Conf#to_immutable `to_immutable`} if the JSI will be immutable.
  #
  #   Default: `false`
  #   @return [Boolean]
  class Base::Conf
    def initialize(
        register: false,
        registry: JSI.registry,
        application_collect_evaluated_validate: false,
        child_as_jsi: :auto,
        child_use_default: false,
        jsi_in_content: :raise,
        stringify_symbol_keys: false,
        to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
        mutable: false,
        **
    )
      super
      self.base_uri = Util.uri(base_uri, nnil: false, yabs: true)
      self.root_uri = Util.uri(root_uri, nnil: false, yabs: true)
    end

    # merge {#stringify_symbol_keys}: `true`
    def symkey
      merge(stringify_symbol_keys: true)
    end

    # merge {#mutable}: `true`
    def mut
      merge(mutable: true)
    end

    # @return [SchemaSet]
    private def instance_root_indicated_schemas(instance)
      root_indicated_schemas
    end

    # @return [Base]
    def call(input)
      raise(BlockGivenError) if block_given?

      input = Util.jsi_in_content(input, action: jsi_in_content)

      input = Util.deep_stringify_symbol_keys(input) if stringify_symbol_keys

      input = to_immutable.call(input) if !mutable && to_immutable

      # input has been transformed into instance
      instance = input

      root_indicated_schemas = instance_root_indicated_schemas(instance)
      applied_schemas = SchemaSet.build do |y|
        c = y.method(:yield) # TODO drop c, just pass y, when all supported Enumerator::Yielder.method_defined?(:to_proc)
        root_indicated_schemas.each { |is| is.each_inplace_applicator_schema(instance, &c) }
      end

      jsi_class = JSI::SchemaClasses.class_for_schemas(applied_schemas,
        includes: SchemaClasses.includes_for(instance),
        mutable: mutable,
      )
      jsi = jsi_class.new(
        jsi_document: instance,
        jsi_indicated_schemas: root_indicated_schemas,
        jsi_base_uri: base_uri || root_uri,
        jsi_conf: self,
      ).send(:jsi_initialized)

      registry.register(jsi) if register && registry

      jsi
    end

    # see {#call} (note this does not access member values as Struct#[] normally does)
    def [](input)
      input.equal?(Util::UNDEFINED) ? self : call(input)
    end

    def to_proc
      proc { |input| call(input) }
    end
  end

  conf_schema_attrs = {
    schema_module_exec: {fingerprint: false},
  }.freeze

  Base::Conf::Schema = Base::Conf.subclass(*conf_schema_attrs.keys)

  Base::Conf::Schema::ATTRS = Base::Conf::ATTRS.merge(conf_schema_attrs)

  # @!attribute schema_module_exec
  #   Passed to {JSI::Schema#jsi_schema_module_exec}
  #   @return [#to_proc, nil]
  class Base::Conf::Schema < Base::Conf
    def initialize(
        register: true,
        stringify_symbol_keys: true,
        **
    )
      super
      raise(ArgumentError, "this method does not instantiate mutable schemas") if mutable
    end

    # @return [Base + Schema]
    def call(*)
      jsi = super
      jsi.jsi_schema_module_exec(&schema_module_exec) if schema_module_exec
      jsi
    end
  end

  class Base::Conf::SchemaModule < Base::Conf::Schema
    # @return [SchemaModule]
    def call(*)
      super.jsi_schema_module
    end
  end

  conf_schema_infer_metaschema_attrs = {
    default_metaschema: {fingerprint: false},
  }.freeze

  Base::Conf::SchemaInferMetaSchema = Base::Conf::Schema.subclass(*conf_schema_infer_metaschema_attrs.keys)

  Base::Conf::SchemaInferMetaSchema::ATTRS = Base::Conf::Schema::ATTRS.merge(conf_schema_infer_metaschema_attrs)

  # @!attribute default_metaschema
  #   Indicates the meta-schema to use if the given `schema_content` does not have a `$schema` property.
  #   This may be a meta-schema or a meta-schema's schema module (e.g. `JSI::JSONSchemaDraft07`),
  #   or a URI (as would be in a `$schema` keyword).
  #   @return [Schema::MetaSchema, SchemaModule::MetaSchemaModule, #to_str]
  class Base::Conf::SchemaInferMetaSchema < Base::Conf::Schema
    # merge {#default_metaschema}: {JSONSchemaDraft04}
    def d4
      merge(default_metaschema: JSONSchemaDraft04)
    end

    # merge {#default_metaschema}: {JSONSchemaDraft06}
    def d6
      merge(default_metaschema: JSONSchemaDraft06)
    end

    # merge {#default_metaschema}: {JSONSchemaDraft07}
    def d7
      merge(default_metaschema: JSONSchemaDraft07)
    end

    # merge {#default_metaschema}: {JSONSchemaDraft202012}
    def d20
      merge(default_metaschema: JSONSchemaDraft202012)
    end

    private def instance_root_indicated_schemas(schema_content)
      if schema_content.respond_to?(:to_hash) && (id = schema_content['$schema'] || stringify_symbol_keys && schema_content[:'$schema'])
        SchemaSet[Schema.ensure_metaschema(id, name: '$schema', registry: registry)]
      elsif default_metaschema
        SchemaSet[Schema.ensure_metaschema(default_metaschema, name: 'default_metaschema', registry: registry)]
      elsif JSI.default_metaschema
        SchemaSet[JSI.default_metaschema]
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
    end
  end

  class Base::Conf::SchemaModuleInferMetaSchema < Base::Conf::SchemaInferMetaSchema
    # @return [SchemaModule]
    def call(*)
      super.jsi_schema_module
    end
  end
end
