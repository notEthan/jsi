# frozen_string_literal: true

module JSI
  conf_attrs = {
    root_uri:                               {fingerprint: true },
    registry:                               {fingerprint: true },
    application_collect_evaluated_validate: {fingerprint: false},
    reinstantiate_nonschemas:               {fingerprint: false},
    after_initialize:                       {fingerprint: false},
    child_as_jsi:                           {fingerprint: false},
    child_use_default:                      {fingerprint: false},
    to_immutable:                           {fingerprint: false},
  }.freeze
  Base::Conf = Struct.subclass(*conf_attrs.keys)
  class Base::Conf end
  Base::Conf::ATTRS = conf_attrs

  # Configuration, shared across all nodes of a document. A JSI's {Base#jsi_conf}.
  #
  # Configuration parameters are set from `**conf_kw` params passed to {SchemaSet#new_jsi #new_jsi},
  # {Schema::MetaSchema#new_schema #new_schema} and related methods.
  #
  # @!attribute root_uri
  #   A URI identifying the document root resource.
  #   References (e.g. a schema `$ref`) can resolve the resource with this URI.
  #
  #   It is rare that this needs to be specified. Most resources that would be
  #   referenced are schemas that use the `$id` keyword to specify their URI.
  #   However, there are cases when a resource may be referenced using a retrieval URI
  #   that does not match the resource's `$id`, and `root_uri` enables resolution.
  #   @return [URI, nil]
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
  class Base::Conf
    def initialize(
        root_uri: nil,
        registry: JSI.registry,
        application_collect_evaluated_validate: false,
        child_as_jsi: :auto,
        child_use_default: false,
        to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE,
        **kw
    )
      super(
        root_uri: Util.uri(root_uri, nnil: false, yabs: true),
        registry: registry,
        application_collect_evaluated_validate: application_collect_evaluated_validate,
        child_as_jsi: child_as_jsi,
        child_use_default: child_use_default,
        to_immutable: to_immutable,
        **kw,
      )
      freeze
    end

    # @private
    # @return [Hash]
    def for_fingerprint
      to_h.select { |k, _| self.class::ATTRS.fetch(k).fetch(:fingerprint) }.freeze
    end
  end
end
