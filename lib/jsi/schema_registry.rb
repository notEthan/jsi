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
    # each descendent node of the resource (including the resource itself) is registered if it is a schema
    # that has an absolute URI (generally defined by the '$id' keyword).
    #
    # the given resource itself will be registered, whether or not it is a schema, if it is the root
    # of its document and was instantiated with the option `uri` specified.
    #
    # @param resource [JSI::Base] a JSI containing resources to register
    # @return [void]
    def register(resource)
      unless resource.is_a?(JSI::Base)
        raise(ArgumentError, "resource must be a JSI::Base. got: #{resource.pretty_inspect.chomp}")
      end
      unless resource.is_a?(JSI::Schema) || resource.jsi_ptr.root?
        # unsure, should this be allowed? the given JSI is not a "resource" as we define it, but
        # if this check is removed it will just register any resources (schemas) below the given JSI.
        raise(ArgumentError, "undefined behavior: registration of a JSI which is not a schema and is not at the root of a document")
      end

      # allow for registration of resources at the root of a document whether or not they are schemas.
      # jsi_schema_base_uri at the root comes from the `uri` parameter to new_jsi / new_schema.
      if resource.jsi_schema_base_uri && resource.jsi_ptr.root?
        register_single(resource.jsi_schema_base_uri, resource)
      end

      resource.jsi_each_descendent_node do |node|
        if node.is_a?(JSI::Schema) && node.schema_absolute_uri
          register_single(node.schema_absolute_uri, node)
        end
      end

      nil
    end

    # takes a URI identifying a resource to be loaded by the given block
    # when a reference to the URI is followed.
    #
    # for example:
    #
    #     JSI.schema_registry.autoload_uri('http://example.com/schema.json') do
    #       JSI.new_schema({
    #         '$schema' => 'http://json-schema.org/draft-07/schema#',
    #         '$id' => 'http://example.com/schema.json',
    #         'title' => 'my schema',
    #       })
    #     end
    #
    # the block would normally load JSON from the filesystem or similar.
    #
    # @param uri [Addressable::URI]
    # @yieldreturn [JSI::Base] a JSI instance containing the resource identified by the given uri
    # @return [void]
    def autoload_uri(uri, &block)
      uri = Util.uri(uri)
      ensure_uri_absolute(uri)
      @autoload_uris[uri] = block
      nil
    end

    # @param uri [Addressable::URI, #to_str]
    # @return [JSI::Base]
    # @raise [JSI::SchemaRegistry::ResourceNotFound]
    def find(uri)
      uri = Util.uri(uri)
      ensure_uri_absolute(uri)
      if @autoload_uris.key?(uri) && !@resources.key?(uri)
        autoloaded = @autoload_uris[uri].call
        register(autoloaded)
      end
      registered_uris = @resources.keys
      if !registered_uris.include?(uri)
        if @autoload_uris.key?(uri)
          msg = [
            "URI #{uri} was registered with autoload_uri but the result did not contain a resource with that URI.",
            "the resource resulting from autoload_uri was:",
            autoloaded.pretty_inspect.chomp,
          ]
        else
          msg = ["URI #{uri} is not registered. registered URIs:", *registered_uris]
        end
        raise(ResourceNotFound, msg.join("\n"))
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
        raise(NonAbsoluteURI, "#{self.class} only registers absolute URIs. cannot access URI with fragment: #{uri}")
      end
      if uri.relative?
        raise(NonAbsoluteURI, "#{self.class} only registers absolute URIs. cannot access relative URI: #{uri}")
      end
    end
  end
end
