module JSI
  # @private
  # a node in a document which may contain a schema somewhere within is extended with SchemaAncestorNode, for
  # tracking things necessary for a schema to function correctly
  module Schema::SchemaAncestorNode
    # @private
    # @return [Addressable::URI, nil] the base URI used to resolve the ids of schemas at or below this JSI.
    #   this is always an absolute URI (with no fragment).
    #   this may be the absolute schema URI of a parent schema or the URI from which the document was retrieved.
    attr_reader :jsi_schema_base_uri

    # @private
    # @return [Array<JSI::Schema>] schema resources which are ancestors of this JSI.
    #   this does not include self.
    def jsi_schema_resource_ancestors
      return @jsi_schema_resource_ancestors if instance_variable_defined?(:@jsi_schema_resource_ancestors)
      [].freeze
    end

    private

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
      @jsi_schema_resource_ancestors = jsi_schema_resource_ancestors
    end
  end
end
