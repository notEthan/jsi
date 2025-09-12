# frozen_string_literal: true

module JSI
  # a node in a document which may contain a schema somewhere within is extended with SchemaAncestorNode, for
  # tracking things necessary for a schema to function correctly
  module Schema::SchemaAncestorNode
    if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
      def initialize(*)
        super
        jsi_schema_ancestor_node_initialize
      end
    else
      def initialize(*, **)
        super
        jsi_schema_ancestor_node_initialize
      end
    end

    # Base URI for URI resolution - always an absolute URI (with no fragment).
    # If this node is a resource, its {#jsi_resource_uri} (i.e. its `$id`) is resolved against this URI, if that is relative.
    #
    # At the root this comes from param `base_uri` of {SchemaSet#new_jsi new_jsi}/{JSI.new_schema new_schema},
    # or from a configured {Base::Conf#root_uri root_uri}.
    # Below the root this comes from the parent's {#jsi_next_base_uri}.
    # @return [URI, nil]
    attr_reader(:jsi_base_uri)

    # @deprecated after v0.8
    def jsi_schema_base_uri
      jsi_base_uri
    end

    # resources which are ancestors of this JSI in the document. this does not include self.
    # @api private
    # @return [Array<JSI::Schema>]
    attr_reader :jsi_schema_resource_ancestors

    # @return [Schema::DynamicAnchorMap]
    # @api private
    attr_reader(:jsi_schema_dynamic_anchor_map)

    # @deprecated after v0.8
    def jsi_schema_registry
      jsi_registry
    end

    # See {Base#jsi_resource_root}
    # @return [Schema::SchemaAncestorNode, nil]
    def jsi_resource_root
      # overridden by Base. may be nil from MetaSchemaNode::BootstrapSchema.
      jsi_is_resource_root? ? self : jsi_schema_resource_ancestors.last
    end

    # @return [Boolean]
    def jsi_is_resource_root?
      # overridden by Schema
      jsi_ptr.root?
    end

    # An absolute URI identifying this node, if this node is a resource root.
    # Typically from a schema's `$id` keyword.
    # @return [URI, nil]
    def jsi_resource_uri
      jsi_resource_uris.first
    end

    # Absolute URIs identifying this node - typically one URI if this is a resource root, otherwise none.
    # @return [Enumerable<URI>]
    def jsi_resource_uris
      @resource_uris_map[content: jsi_node_content]
    end

    # @yield [URI]
    private def jsi_each_resource_uri_compute
      yield jsi_root_uri if jsi_ptr.root? && jsi_root_uri
    end

    # URI for resolution of relative URIs at or below this node - always an absolute URI (with no fragment).
    # Mainly used to resolve relative `$ref`s.
    # This is self's {#jsi_resource_uri} if this node is a resource; otherwise {#jsi_base_uri}.
    # @return [URI, nil]
    def jsi_next_base_uri
      jsi_resource_uri || jsi_base_uri
    end

    # @private
    # @param dynamic_anchor_map [Schema::DynamicAnchorMap]
    # @return [Schema::SchemaAncestorNode]
    def jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
      if dynamic_anchor_map == jsi_schema_dynamic_anchor_map
        return self
      end

      if jsi_resource_root
        # it might seem to make more sense to keep dynamic scope from the resource_root, merged with given scope, e.g.:
        #new_dynamic_anchor_map = resource_root.jsi_next_schema_dynamic_anchor_map.merge(dynamic_anchor_map).without_node(resource_root)
        # except the json schema test suite has (optional) tests "$dynamicRef skips over intermediate resources"
        new_dynamic_anchor_map = dynamic_anchor_map.without_node(jsi_resource_root)
        if new_dynamic_anchor_map == jsi_schema_dynamic_anchor_map
          return self
        end
      else
        new_dynamic_anchor_map = dynamic_anchor_map
      end

      jsi_dynamic_root_descendent(new_dynamic_anchor_map)
    end

    # All schemas at or below this node with the given anchor.
    #
    # @return [Set<JSI::Schema>]
    def jsi_anchor_subschemas(anchor)
      @anchor_subschemas_map[anchor: anchor, content: jsi_node_content]
    end

    private

    BY_ANCHOR = proc { |i| i[:anchor] }

    def jsi_schema_ancestor_node_initialize
      @resource_uris_map = jsi_memomap(key_by: Schema::KEY_BY_NONE) { Set.new(to_enum(:jsi_each_resource_uri_compute)).freeze }
      @anchor_subschemas_map = jsi_memomap(key_by: BY_ANCHOR, &method(:jsi_anchor_subschemas_compute))
    end

    def jsi_base_uri=(jsi_base_uri)
      #chkbug fail(Bug) if jsi_base_uri && !jsi_base_uri.is_a?(URI)
      #chkbug fail(Bug) if jsi_base_uri && !jsi_base_uri.absolute?
      #chkbug fail(Bug) if jsi_base_uri && jsi_base_uri.fragment

      @jsi_base_uri = jsi_base_uri
    end

    def jsi_schema_resource_ancestors=(jsi_schema_resource_ancestors)
      #chkbug fail(Bug) unless jsi_schema_resource_ancestors.respond_to?(:to_ary)
      #chkbug jsi_schema_resource_ancestors.each { |a| Schema.ensure_schema(a) }
      #chkbug # sanity check the ancestors are in order
      #chkbug last_anc_ptr = nil
      #chkbug jsi_schema_resource_ancestors.each do |anc|
      #chkbug   if last_anc_ptr.nil?
      #chkbug     # pass
      #chkbug   elsif last_anc_ptr == anc.jsi_ptr
      #chkbug     fail(Bug, "duplicate ancestors in #{jsi_schema_resource_ancestors.pretty_inspect}")
      #chkbug   elsif !last_anc_ptr.ancestor_of?(anc.jsi_ptr)
      #chkbug     fail(Bug, "ancestor ptr #{anc.jsi_ptr} not descendent of previous: #{last_anc_ptr} in #{jsi_schema_resource_ancestors.pretty_inspect}")
      #chkbug   end
      #chkbug   if anc.jsi_ptr == jsi_ptr
      #chkbug     fail(Bug, "ancestor is self")
      #chkbug   elsif !anc.jsi_ptr.ancestor_of?(jsi_ptr)
      #chkbug     fail(Bug, "ancestor does not contain self")
      #chkbug   end
      #chkbug   last_anc_ptr = anc.jsi_ptr
      #chkbug end

      @jsi_schema_resource_ancestors = jsi_schema_resource_ancestors
    end

    def jsi_schema_dynamic_anchor_map=(dynamic_anchor_map)
      #chkbug fail if !dynamic_anchor_map.is_a?(Schema::DynamicAnchorMap)
      #chkbug fail if !dynamic_anchor_map.frozen?
      #chkbug fail if dynamic_anchor_map != dynamic_anchor_map.without_node(self)
      @jsi_schema_dynamic_anchor_map = dynamic_anchor_map
    end

    def jsi_anchor_subschemas_compute(anchor: , content: )
      SchemaSet.new(jsi_each_descendent_schema_same_resource.select do |schema|
        schema.anchors.include?(anchor)
      end)
    end

    # @return [Util::MemoMap]
    def jsi_memomap(**options, &block)
      jsi_memomap_class.new(**options, &block)
    end
  end
end
