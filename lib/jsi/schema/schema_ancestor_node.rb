module JSI
  # a node in a document which may contain a schema somewhere within is extended with SchemaAncestorNode, for
  # tracking things necessary for a schema to function correctly
  module Schema::SchemaAncestorNode
    # @private
    # @return [Addressable::URI, nil] the base URI used to resolve the ids of schemas at or below this JSI.
    #   this is always an absolute URI (with no fragment).
    #   this may be the absolute schema URI of a parent schema or the URI from which the document was retrieved.
    attr_reader :jsi_schema_base_uri

    # @private
    # @return [Array<JSI::Schema>] resources which are ancestors of this JSI in the document.
    #   this does not include self.
    def jsi_schema_resource_ancestors
      return @jsi_schema_resource_ancestors if instance_variable_defined?(:@jsi_schema_resource_ancestors)
      [].freeze
    end

    # @return [Addressable::URI, nil] the URI of the resource containing this node.
    #   this is always an absolute URI (with no fragment).
    #   if this node is a schema with an id, this is its absolute URI; otherwise a parent resource's URI,
    #   or nil if not contained by a resource with a URI.
    def jsi_resource_ancestor_uri
      if is_a?(Schema) && schema_absolute_uri
        schema_absolute_uri
      else
        jsi_schema_base_uri
      end
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
        end

        @jsi_schema_resource_ancestors = jsi_schema_resource_ancestors.to_ary.freeze
      else
        @jsi_schema_resource_ancestors = [].freeze
      end
    end
  end
end
