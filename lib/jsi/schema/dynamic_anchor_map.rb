# frozen_string_literal: true

module JSI
  # A map of dynamic anchors to schemas.
  #
  # key: `anchor_name` [String] a `$dynamicAnchor` keyword value
  #
  # value: [Array] (2-tuple)
  #
  #   - `anchor_root` [Schema]
  #
  #     Typically the resource root of the schema containing the `$dynamicAnchor` with `anchor_name`,
  #     although this may be a non-resource-root schema when the resource root is the document root and is
  #     not a schema, or the schema is a non-root bootstrap schema with no `jsi_schema_resource_ancestors`.
  #
  #     Note: the `#jsi_schema_dynamic_anchor_map` of anchor_root should not be used.
  #     It should be replaced when the anchor schema is resolved.
  #
  #   - `ptrs` [Array<{Ptr}>]
  #
  #     Pointers passed to {Schema#subschema} from `anchor_root`, resulting in the schema containing the
  #     `$dynamicAnchor` with `anchor_name`.
  #
  # @api private
  class Schema::DynamicAnchorMap < Hash
  end
end
