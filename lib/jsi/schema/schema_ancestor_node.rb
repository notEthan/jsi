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

    # the base URI used to resolve the ids of schemas at or below this JSI.
    # this is always an absolute URI (with no fragment).
    # This may be the absolute schema URI of an ancestor schema or the URI from which the document was retrieved.
    # @api private
    # @return [URI, nil]
    attr_reader :jsi_schema_base_uri

    # resources which are ancestors of this JSI in the document. this does not include self.
    # @api private
    # @return [Array<JSI::Schema>]
    attr_reader :jsi_schema_resource_ancestors

    # See {SchemaSet#new_jsi} param `schema_registry`
    # @return [SchemaRegistry, nil]
    attr_reader(:jsi_schema_registry)

    # the URI of the resource containing this node.
    # this is always an absolute URI (with no fragment).
    # If this node is a schema with an id, this is its absolute URI; otherwise an ancestor resource's URI,
    # or nil if not contained by a resource with a URI.
    # @return [URI, nil]
    def jsi_resource_ancestor_uri
      (is_a?(Schema) && schema_absolute_uri) || jsi_schema_base_uri
    end

    # All schemas at or below this node with the given anchor.
    #
    # @return [Set<JSI::Schema>]
    def jsi_anchor_subschemas(anchor)
      @anchor_subschemas_map[anchor: anchor]
    end

    private

    def jsi_schema_ancestor_node_initialize
      @anchor_subschemas_map = jsi_memomap(&method(:jsi_anchor_subschemas_compute))
    end

    attr_writer :jsi_document

    def jsi_ptr=(jsi_ptr)
      #chkbug fail(Bug, "jsi_ptr not #{Ptr}: #{jsi_ptr}") unless jsi_ptr.is_a?(Ptr)
      @jsi_ptr = jsi_ptr
    end

    def jsi_schema_base_uri=(jsi_schema_base_uri)
      #chkbug fail(Bug) if jsi_schema_base_uri && !jsi_schema_base_uri.is_a?(URI)
      #chkbug fail(Bug) if jsi_schema_base_uri && !jsi_schema_base_uri.absolute?
      #chkbug fail(Bug) if jsi_schema_base_uri && jsi_schema_base_uri.fragment

      @jsi_schema_base_uri = jsi_schema_base_uri
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

    attr_writer(:jsi_schema_registry)

    def jsi_anchor_subschemas_compute(anchor: )
      jsi_each_descendent_schema_same_resource.select do |schema|
        schema.anchors.include?(anchor)
      end.to_set.freeze
    end

    # @return [Util::MemoMap]
    def jsi_memomap(**options, &block)
      jsi_memomap_class.new(**options, &block)
    end
  end
end
