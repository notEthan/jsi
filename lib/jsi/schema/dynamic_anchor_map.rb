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
    # In order to avoid instantiating a node with a dynamic_anchor_map that refers to that node itself
    # (which results in its jsi_fingerprint circularly referring to itself)
    # we remove such anchors from the dynamic_anchor_map it will be instantiated with.
    # The node's #jsi_next_schema_dynamic_anchor_map will remap such anchors to the node again.
    # @return [Schema::DynamicAnchorMap]
    def without_node(node, document: node.jsi_document, ptr: node.jsi_ptr, registry: node.jsi_registry)
      dynamic_anchor_map = self
      dynamic_anchor_map.each do |anchor, (anchor_root, anchor_ptrs)|
        # Determine whether this anchor maps to the indicated node.
        # This should strictly use the same fields as the node's #jsi_fingerprint
        # (which is different for Base, MetaSchemaNode, and MetaSchemaNode::BootstrapSchema).
        # However, some fields of the fingerprint are fairly complicated to compute with neither
        # the node being removed nor the anchor schema actually instantiated.
        # Realistically document+ptr is sufficient and correct outside of implausible edge cases.
        maps_to_node = anchor_root.jsi_document == document &&
          anchor_ptrs.inject(anchor_root.jsi_ptr, &:+) == ptr &&
          anchor_root.jsi_registry == registry
        if maps_to_node
          dynamic_anchor_map = dynamic_anchor_map.dup
          dynamic_anchor_map.delete(anchor)
          dynamic_anchor_map.freeze
        end
      end
      dynamic_anchor_map.empty? ? EMPTY : dynamic_anchor_map
    end

    EMPTY = new.freeze
  end
end
