# frozen_string_literal: true

module JSI
  # a node in a document which may contain a schema somewhere within is extended with SchemaAncestorNode, for
  # tracking things necessary for a schema to function correctly
  module Schema::SchemaAncestorNode
    # the base URI used to resolve the ids of schemas at or below this JSI.
    # this is always an absolute URI (with no fragment).
    # this may be the absolute schema URI of a parent schema or the URI from which the document was retrieved.
    # @api private
    # @return [Addressable::URI, nil]
    attr_reader :jsi_schema_base_uri

    # resources which are ancestors of this JSI in the document. this does not include self.
    # @api private
    # @return [Array<JSI::Schema>]
    def jsi_schema_resource_ancestors
      return @jsi_schema_resource_ancestors if instance_variable_defined?(:@jsi_schema_resource_ancestors)
      Util::EMPTY_ARY
    end

    # the URI of the resource containing this node.
    # this is always an absolute URI (with no fragment).
    # if this node is a schema with an id, this is its absolute URI; otherwise a parent resource's URI,
    # or nil if not contained by a resource with a URI.
    # @return [Addressable::URI, nil]
    def jsi_resource_ancestor_uri
      if is_a?(Schema) && schema_absolute_uri
        schema_absolute_uri
      else
        jsi_schema_base_uri
      end
    end

    # a schema at or below this node with the given anchor.
    #
    # @return [JSI::Schema, nil]
    def jsi_anchor_subschema(anchor)
      subschemas = jsi_anchor_subschemas_map[anchor: anchor]
      if subschemas.size == 1
        subschemas.first
      else
        nil
      end
    end

    # schemas at or below node with the given anchor.
    #
    # @return [Array<JSI::Schema>]
    def jsi_anchor_subschemas(anchor)
      jsi_anchor_subschemas_map[anchor: anchor]
    end

    private

    def jsi_document=(jsi_document)
      @jsi_document = jsi_document
    end

    def jsi_ptr=(jsi_ptr)
      unless jsi_ptr.is_a?(Ptr)
        raise(TypeError, "jsi_ptr must be a JSI::Ptr; got: #{jsi_ptr.inspect}")
      end
      @jsi_ptr = jsi_ptr
    end

    def jsi_schema_base_uri=(jsi_schema_base_uri)
      if jsi_schema_base_uri
        unless jsi_schema_base_uri.respond_to?(:to_str)
          raise(TypeError, "jsi_schema_base_uri must be string or Addressable::URI; got: #{jsi_schema_base_uri.inspect}")
        end
        @jsi_schema_base_uri = Addressable::URI.parse(jsi_schema_base_uri).freeze
        unless @jsi_schema_base_uri.absolute? && !@jsi_schema_base_uri.fragment
          raise(ArgumentError, "jsi_schema_base_uri must be an absolute URI with no fragment; got: #{jsi_schema_base_uri.inspect}")
        end
      else
        @jsi_schema_base_uri = nil
      end
    end

    def jsi_schema_resource_ancestors=(jsi_schema_resource_ancestors)
      if jsi_schema_resource_ancestors
        unless jsi_schema_resource_ancestors.respond_to?(:to_ary)
          raise(TypeError, "jsi_schema_resource_ancestors must be an array; got: #{jsi_schema_resource_ancestors.inspect}")
        end
        jsi_schema_resource_ancestors.each { |a| Schema.ensure_schema(a)  }
        # sanity check the ancestors are in order
        last_anc_ptr = nil
        jsi_schema_resource_ancestors.each do |anc|
          if last_anc_ptr.nil?
            # pass
          elsif last_anc_ptr == anc.jsi_ptr
            raise(Bug, "duplicate ancestors in #{jsi_schema_resource_ancestors.pretty_inspect}")
          elsif !last_anc_ptr.contains?(anc.jsi_ptr)
            raise(Bug, "ancestor ptr #{anc.jsi_ptr} not contained by previous: #{last_anc_ptr} in #{jsi_schema_resource_ancestors.pretty_inspect}")
          end
          if anc.jsi_ptr == jsi_ptr
            raise(Bug, "ancestor is self")
          elsif !anc.jsi_ptr.contains?(jsi_ptr)
            raise(Bug, "ancestor does not contain self")
          end
          last_anc_ptr = anc.jsi_ptr
        end

        @jsi_schema_resource_ancestors = jsi_schema_resource_ancestors.to_ary.freeze
      else
        @jsi_schema_resource_ancestors = Util::EMPTY_ARY
      end
    end

    def jsi_anchor_subschemas_map
      jsi_memomap(__method__) do |anchor: |
        jsi_each_descendent_node.select do |node|
          node.is_a?(Schema) && node.respond_to?(:anchor) && node.anchor == anchor
        end.freeze
      end
    end
  end
end
