# frozen_string_literal: true

module JSI
  class Registry
    # an exception raised when an attempt is made to register a resource using a URI which is already
    # registered with another resource
    class Collision < StandardError
    end

    # @deprecated alias after v0.8
    # an exception raised when a URI we are looking for has not been registered
    ResourceNotFound = ResolutionError

    include(Util::Pretty)

    def initialize
      @resources = {}
      @resource_autoloaders = {}
      @vocabularies = {}
      @vocabulary_autoloaders = {}
      @dialects = {}
      @dialect_autoloaders = {}
      @mutex = Mutex.new
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
      unless resource.is_a?(Base) || resource.is_a?(Schema)
        raise(ArgumentError, "resource must be a #{Base}. got: #{resource.pretty_inspect.chomp}")
      end
      unless resource.is_a?(JSI::Schema) || resource.jsi_ptr.root?
        # unsure, should this be allowed? the given JSI is not a "resource" as we define it, but
        # if this check is removed it will just register any resources (schemas) below the given JSI.
        raise(ArgumentError, "undefined behavior: registration of a JSI which is not a schema and is not at the root of a document")
      end

      # allow for registration of resources at the root of a document whether or not they are schemas.
      # jsi_schema_base_uri at the root comes from the `uri` parameter to new_jsi / new_schema.
      if resource.jsi_schema_base_uri && resource.jsi_ptr.root?
        internal_store(@resources, resource.jsi_schema_base_uri, resource)
      end

      resource.jsi_each_descendent_schema do |node|
        register_immediate(node)
      end
    end

    # @param schema [Schema]
    # @return [void]
    def register_immediate(schema)
      schema.schema_absolute_uris.each do |uri|
        internal_store(@resources, uri, schema)
      end
    end

    # takes a URI identifying a resource to be loaded by the given block
    # when a reference to the URI is followed.
    #
    # for example:
    #
    #     JSI.registry.autoload_uri('http://example.com/schema.json') do
    #       JSI.new_schema({
    #         '$schema' => 'http://json-schema.org/draft-07/schema#',
    #         '$id' => 'http://example.com/schema.json',
    #         'title' => 'my schema',
    #       })
    #     end
    #
    # the block would normally load JSON from the filesystem or similar.
    #
    # @param uri [#to_str]
    # @yieldreturn [JSI::Base] a JSI instance containing the resource identified by the given uri
    # @return [void]
    def autoload_uri(uri, &block)
      internal_autoload(@resource_autoloaders, uri, block)
    end

    private def internal_autoload(autoloaders, uri, block)
      uri = registration_uri(uri)
      mutating
      unless block
        raise(ArgumentError, ["#{Registry} autoload must be invoked with a block", "URI: #{uri}"].join("\n"))
      end
      if autoloaders.key?(uri)
        raise(Collision, ["already registered URI for autoload", "URI: #{uri}", "loader: #{autoloaders[uri]}"].join("\n"))
      end
      autoloaders[uri] = block
      nil
    end

    # @param uri [URI, #to_str]
    # @return [JSI::Base]
    # @raise [ResolutionError]
    def find(uri)
      internal_find(uri, @resources, @resource_autoloaders, proc { |r, _| register(r) }, 'resource')
    end

    private def internal_find(uri, store, autoloaders, registerer, typename)
      uri = registration_uri(uri)
      if autoloaders.key?(uri)
        autoload_param = {
          registry: self,
          uri: uri,
        }
        # remove params the autoload proc does not accept
        autoload_param.select! do |name, _|
          autoloaders[uri].parameters.any? do |type, pname|
            # dblsplat (**k) ||   required (k: )  || optional (k: nil)
            type == :keyrest || ((type == :keyreq || type == :key) && pname == name)
          end
        end
        autoloaded = autoloaders[uri].call(**autoload_param)
        registerer[autoloaded, uri]
        autoloaders.delete(uri)
      end
      if !store.key?(uri)
        if autoloaded
          msg = [
            "#{typename} URI #{uri} was registered for autoload but the result did not contain an entity with that URI.",
            "autoload result was:",
            autoloaded.pretty_inspect.chomp,
          ]
        else
          msg = ["#{typename} URI #{uri} is not registered. registered URIs:", *(store.keys | autoloaders.keys)]
        end
        raise(ResolutionError.new(msg, uri: uri))
      end
      store[uri]
    end

    # @param uri [#to_str]
    # @return [Boolean]
    def registered?(uri)
      uri = registration_uri(uri)
      @resources.key?(uri) || @resource_autoloaders.key?(uri)
    end

    # @param vocabulary [Schema::Vocabulary]
    # @param uri [#to_str]
    # @return [void]
    def register_vocabulary(vocabulary, uri: vocabulary.id)
      raise(ArgumentError, "not a #{Schema::Vocabulary}: #{vocabulary.inspect}") if !vocabulary.is_a?(Schema::Vocabulary)
      internal_store(@vocabularies, uri, vocabulary)
    end

    # @param uri [#to_str]
    # @yieldreturn [Schema::Vocabulary]
    # @return [void]
    def autoload_vocabulary_uri(uri, &block)
      internal_autoload(@vocabulary_autoloaders, uri, block)
    end

    # @param uri [#to_str]
    # @return [Schema::Vocabulary]
    # @raise [ResolutionError]
    def find_vocabulary(uri)
      internal_find(uri, @vocabularies, @vocabulary_autoloaders, proc { |v, uri| register_vocabulary(v, uri: uri) }, 'vocabulary')
    end

    # @param uri [#to_str]
    # @return [Boolean]
    def vocabulary_registered?(uri)
      uri = registration_uri(uri)
      @vocabularies.key?(uri) || @vocabulary_autoloaders.key?(uri)
    end

    # @param dialect [Schema::Dialect]
    # @param uri [#to_str]
    # @return [void]
    def register_dialect(dialect, uri: dialect.id)
      raise(ArgumentError, "not a #{Schema::Dialect}: #{dialect.inspect}") if !dialect.is_a?(Schema::Dialect)
      internal_store(@dialects, uri, dialect)
    end

    # @param uri [#to_str]
    # @yieldreturn [Schema::Dialect]
    # @return [void]
    def autoload_dialect_uri(uri, &block)
      internal_autoload(@dialect_autoloaders, uri, block)
    end

    # @param uri [#to_str]
    # @return [Schema::Dialect]
    # @raise [ResolutionError]
    def find_dialect(uri)
      internal_find(uri, @dialects, @dialect_autoloaders, proc { |v, uri| register_dialect(v, uri: uri) }, 'dialect')
    end

    # @param uri [#to_str]
    # @return [Boolean]
    def dialect_registered?(uri)
      uri = registration_uri(uri)
      @dialects.key?(uri) || @dialect_autoloaders.key?(uri)
    end

    def pretty_print(q)
      jsi_pp_object_group(q) do
        labels_uris = [
          ['resources', @resources.keys],
          ['resources autoload', @resource_autoloaders.keys],
          ['vocabularies', @vocabularies.keys],
          ['vocabularies autoload', @vocabulary_autoloaders.keys],
          ['dialects', @dialects.keys],
          ['dialects autoload', @dialect_autoloaders.keys],
        ]
        q.seplist(labels_uris, q.method(:breakable)) do |label, uris|
          q.text("#{label} (#{uris.size})")
          if !uris.empty?
            q.text(": <")
            q.group do
              q.nest(2) do
                q.breakable('')
                q.seplist(uris) do |uri|
                  q.text(uri.to_s.inspect)
                end
              end
              q.breakable('')
            end
            q.text '>'
          end
        end
      end
    end

    def dup
      self.class.new.tap do |reg|
        reg.instance_variable_get(:@resources).update(@resources)
        reg.instance_variable_get(:@resource_autoloaders).update(@resource_autoloaders)
        reg.instance_variable_get(:@vocabularies).update(@vocabularies)
        reg.instance_variable_get(:@vocabulary_autoloaders).update(@vocabulary_autoloaders)
        reg.instance_variable_get(:@dialects).update(@dialects)
        reg.instance_variable_get(:@dialect_autoloaders).update(@dialect_autoloaders)
      end
    end

    def freeze
      @resources.freeze
      @resource_autoloaders.freeze
      @vocabularies.freeze
      @vocabulary_autoloaders.freeze
      @dialects.freeze
      @dialect_autoloaders.freeze
      @mutex = nil
      super
    end

    protected
    # @param store [Hash]
    # @param uri [URI]
    # @param entity
    # @return [void]
    def internal_store(store, uri, entity)
      mutating
      @mutex.synchronize do
        uri = registration_uri(uri)
        if store.key?(uri)
          if !store[uri].equal?(entity)
            raise(Collision, "URI collision on #{uri}.\nexisting:\n#{store[uri].pretty_inspect.chomp}\nnew:\n#{entity.pretty_inspect.chomp}")
          end
        else
          store[uri] = entity
        end
      end
      nil
    end

    private

    # registration URIs are
    # - absolute
    #   - without fragment
    #   - not relative
    # - normalized
    # - frozen
    # @param uri [#to_str]
    # @return [Addressable::URI]
    def registration_uri(uri)
      Util.uri(uri, nnil: true, yabs: true, tonorm: true)
    end

    def mutating
      if frozen?
        raise(FrozenError, "cannot modify frozen #{self.class}")
      end
    end
  end

  # @deprecated after v0.8
  SchemaRegistry = Registry
end
