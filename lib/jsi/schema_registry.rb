# frozen_string_literal: true

module JSI
  class SchemaRegistry
    # an exception raised when an attempt is made to register a resource using a URI which is already
    # registered with another resource
    class Collision < StandardError
    end

    # an exception raised when an attempt is made to add a resource to the registry using a URI which is
    # not absolute (it is a relative URI or it contains a fragment)
    class NonAbsoluteURIRegistration < StandardError
    end

    def initialize
      @resources = {}
      @resources_mutex = Mutex.new
    end

    # @param resource [JSI::Base]
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

      JSI::Util.ycomb do |rec|
        proc do |node|
          if node.is_a?(JSI::Schema) && node.schema_absolute_uri
            register_single(node.schema_absolute_uri, node)
          end
          if node.respond_to?(:to_hash)
            node.to_hash.values.each(&rec)
          elsif node.respond_to?(:to_ary)
            node.to_ary.each(&rec)
          end
        end
      end.call(resource)
      nil
    end

    private
    # @param uri [Addressable::URI]
    # @param resource [JSI::Base]
    # @return [void]
    def register_single(uri, resource)
      @resources_mutex.synchronize do
        if uri.relative? || uri.fragment
          raise(NonAbsoluteURIRegistration, "cannot register URI which is not absolute: #{id}")
        end
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
  end
end
