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

    # @return [Base]
    def call(input)
      raise(BlockGivenError) if block_given?

      input = Util.jsi_in_content(input, action: jsi_in_content)

      input = Util.deep_stringify_symbol_keys(input) if stringify_symbol_keys

      input = to_immutable.call(input) if !mutable && to_immutable

      # input has been transformed into instance
      instance = input

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

  class Base::Conf::Schema < Base::Conf
    def initialize(
        register: true,
        stringify_symbol_keys: true,
        **
    )
      super
      raise(ArgumentError, "this method does not instantiate mutable schemas") if mutable
    end
  end
end
