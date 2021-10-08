# frozen_string_literal: true

module JSI
  class SchemaRegistry
    # an exception raised when an attempt is made to register a resource using a URI which is already
    # registered with another resource
    class Collision < StandardError
    end

    # an exception raised when an attempt is made to access (register or find) a resource of the
    # registry using a URI which is not absolute (it is a relative URI or it contains a fragment)
    class NonAbsoluteURI < StandardError
    end

    # an exception raised when a URI we are looking for has not been registered
    class ResourceNotFound < StandardError
    end

    def initialize
      @resources = {}
      @autoload_uris = {}
      @resources_mutex = Mutex.new
    end

    # registers the given resource and/or schema resources it contains in the registry.
    #
    # each child of the resource (including the resource itself) is registered if it is a schema that
    # has an absolute URI (generally defined by the '$id' keyword).
    #
    # the given resource itself will be registered, whether or not it is a schema, if it is the root
    # of its document and was instantiated with the option `base_uri` specified.
    #
    # @param resource [JSI::Base] a JSI containing resources to register
    # @return [void]
    def register(resource)
      # allow for registration of resources at the root of a document whether or not they are schemas
      if resource.jsi_schema_base_uri
        if resource.jsi_ptr.root?
          register_single(resource.jsi_schema_base_uri, resource)
        elsif !resource.is_a?(JSI::Schema)
          raise(ArgumentError, "undefined behavior: registration of a JSI which has a base URI, but is not at the root of a document")
        end
      end

      resource.jsi_each_child_node do |node|
        if node.is_a?(JSI::Schema) && node.schema_absolute_uri
          register_single(node.schema_absolute_uri, node)
        end
      end

      nil
    end

    # takes a URI identifying a schema to be loaded by the given block
    # when a reference to the URI is followed.
    #
    # @param uri [Addressable::URI]
    # @yieldreturn [JSI::Base] a document containing the schema identified by the given uri
    # @return [void]
    def autoload_uri(uri, &block)
      uri = Addressable::URI.parse(uri)
      ensure_uri_absolute(uri)
      @autoload_uris[uri] = block
      nil
    end

    # @param uri [Addressable::URI, #to_str]
    # @return [JSI::Base]
    # @raise [JSI::SchemaRegistry::ResourceNotFound]
    def find(uri)
      uri = Addressable::URI.parse(uri)
      ensure_uri_absolute(uri)
      if @autoload_uris.key?(uri) && !@resources.key?(uri)
        register(@autoload_uris[uri].call)
      end
      registered_uris = @resources.keys
      if !registered_uris.include?(uri)
        raise(ResourceNotFound, "URI #{uri} is not registered. registered URIs:\n#{registered_uris.join("\n")}")
      end
      @resources[uri]
    end

    def dup
      self.class.new.tap do |reg|
        @resources.each do |uri, resource|
          reg.register_single(uri, resource)
        end
        @autoload_uris.each do |uri, autoload|
          reg.autoload_uri(uri, &autoload)
        end
      end
    end

    protected
    # @param uri [Addressable::URI]
    # @param resource [JSI::Base]
    # @return [void]
    def register_single(uri, resource)
      @resources_mutex.synchronize do
        ensure_uri_absolute(uri)
        if @resources.key?(uri)
          if @resources[uri] != resource
            raise(Collision, "URI collision on #{uri}.\nexisting:\n#{@resources[uri].pretty_inspect.chomp}\nnew:\n#{resource.pretty_inspect.chomp}")
          end
        else
          @resources[uri] = resource
        end
      end
      nil
    end

    private

    def ensure_uri_absolute(uri)
      if uri.fragment
        raise(NonAbsoluteURI, "SchemaRegistry only registers absolute URIs. cannot access URI with fragment: #{uri}")
      end
      if uri.relative?
        raise(NonAbsoluteURI, "SchemaRegistry only registers absolute URIs. cannot access relative URI: #{uri}")
      end
    end
  end
end
