# frozen_string_literal: true

module JSI
  # A reference to a JSI identified by a given URI.
  class Ref
    include(Util::Pretty)

    # @param ref [#to_str] A reference URI, e.g. a `$ref` value of a referrer schema
    # @param referrer [Base] A JSI from which the reference originated.
    #
    #   If the ref URI consists of only a fragment, it is resolved from the `referrer`'s
    #   root (its {Schema#schema_resource_root} if resolving a {Schema::Ref}; its document root if not).
    #   Otherwise the resource is found in the `referrer`'s
    #   `#jsi_registry` (and any fragment is resolved from there).
    # @param registry [Registry, nil] The registry in which the resource this ref refers to will be found.
    #   If `referrer` is specified and `registry` is not, defaults to its `#jsi_registry`.
    #   If neither is specified, {JSI.registry} is used.
    def initialize(ref, referrer: nil, registry: (registry_undefined = true))
      raise(ArgumentError, "ref is not a string") unless ref.respond_to?(:to_str)
      @ref = ref
      @ref_uri = Util.uri(ref, nnil: true)
      @referrer = referrer && resolve_schema? ? Schema.ensure_schema(referrer) : referrer
      @registry = !registry_undefined ? registry
      : referrer ? referrer.jsi_registry
      : JSI.registry
      @resolved = nil
    end

    # @return [#to_str]
    attr_reader :ref

    # @return [URI]
    attr_reader :ref_uri

    # @return [Base, nil]
    attr_reader(:referrer)

    # @return [Registry, nil]
    attr_reader(:registry)

    # @return [Boolean]
    def resolve_schema?
      false
    end

    # Resolves the target of this reference.
    # @return [JSI::Base]
    # @raise [JSI::Schema::NotASchemaError] when the resolved target must be a Schema but is not
    # @raise [ResolutionError] when this reference cannot be resolved
    def resolve
      return @resolved if @resolved

      resource_root = nil
      check_resource_root = proc {
        unless resource_root
          raise(ResolutionError.new([
            "cannot resolve ref: #{ref}",
            ("from: #{referrer.pretty_inspect.chomp}" if referrer),
          ], uri: ref_uri))
        end
      }

      ref_uri_nofrag = ref_uri.merge(fragment: nil)

      if ref_uri_nofrag.empty?
        unless referrer
          raise(ResolutionError.new([
            "cannot resolve ref: #{ref}",
            "with no referrer",
          ], uri: ref_uri))
        end

        # the URI only consists of a fragment (or is empty).
        if resolve_schema?
          # for a fragment pointer, resolve using Schema#resource_root_subschema on the referrer.
          # for a fragment anchor, use the referrer's schema_resource_root.
          resource_root = referrer.schema_resource_root # note: may be nil from bootstrap schema
          resolve_fragment_ptr = referrer.method(:resource_root_subschema)
        else
          resource_root = referrer.jsi_root_node
          resolve_fragment_ptr = resource_root.method(:jsi_descendent_node)
        end
      else
        # find the resource_root from the non-fragment URI. we will resolve any fragment, either pointer or anchor, from there.

        if ref_uri_nofrag.absolute?
          ref_abs_uri = ref_uri_nofrag
        elsif referrer && referrer.jsi_resource_ancestor_uri
          ref_abs_uri = referrer.jsi_resource_ancestor_uri.join(ref_uri_nofrag)
        else
          ref_abs_uri = nil
        end
        if ref_abs_uri
          unless registry
            raise(ResolutionError.new([
              "could not resolve remote ref with no registry specified",
              "ref URI: #{ref_uri.to_s}",
              ("from: #{referrer.pretty_inspect.chomp}" if referrer),
            ], uri: ref_uri))
          end
          resource_root = registry.find(ref_abs_uri)
        end

        if !resource_root && resolve_schema?
          # HAX for how google does refs and ids
          if referrer && referrer.jsi_document.respond_to?(:to_hash) && referrer.jsi_document['schemas'].respond_to?(:to_hash)
            referrer.jsi_document['schemas'].each do |k, v|
              if URI[v['id']] == ref_uri_nofrag
                resource_root = referrer.resource_root_subschema(['schemas', k])
              end
            end
          end
        end

        check_resource_root.call

        if resolve_schema? && resource_root.is_a?(Schema)
          resolve_fragment_ptr = resource_root.method(:resource_root_subschema)
        else
          # Note: Schema#resource_root_subschema will reinstantiate nonschemas as schemas.
          # not implemented for remote refs when the resource_root is not a schema.
          resolve_fragment_ptr = proc { |ptr| resource_root.jsi_descendent_node(ptr) }
        end
      end

      fragment = ref_uri.fragment

      if fragment
        begin
          ptr_from_fragment = Ptr.from_fragment(fragment)
        rescue Ptr::PointerSyntaxError
        end
      end

      if ptr_from_fragment
        begin
          resolved = resolve_fragment_ptr.call(ptr_from_fragment)
        rescue Ptr::ResolutionError
          raise(ResolutionError.new([
            "could not resolve pointer: #{ptr_from_fragment.pointer.inspect}",
            ("from: #{referrer.pretty_inspect.chomp}" if referrer),
            ("in resource root: #{resource_root.pretty_inspect.chomp}" if resource_root),
          ], uri: ref_uri))
        end
      elsif fragment.nil?
        check_resource_root.call
        resolved = resource_root
      elsif resolve_schema?
        check_resource_root.call

        # find an anchor that resembles the fragment
        result_schemas = resource_root.jsi_anchor_subschemas(fragment)

        if result_schemas.size == 1
          resolved = result_schemas.first
        elsif result_schemas.size == 0
          raise(ResolutionError.new([
            "could not resolve fragment: #{fragment.inspect}",
            "in resource root: #{resource_root.pretty_inspect.chomp}",
          ], uri: ref_uri))
        else
          raise(ResolutionError.new([
            "found multiple schemas for plain name fragment #{fragment.inspect}:",
            *result_schemas.map { |s| s.pretty_inspect.chomp },
          ], uri: ref_uri))
        end
      else
        raise(ResolutionError.new([
          "could not resolve fragment #{fragment.inspect}. fragment must be a pointer.",
          ("in resource root: #{resource_root.pretty_inspect.chomp}" if resource_root),
        ], uri: ref_uri))
      end

      Schema.ensure_schema(resolved) { "object identified by uri #{ref} is not a schema:" } if resolve_schema?
      return @resolved = resolved
    end

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      jsi_pp_object_group(q, [self.class.name, ref].freeze)
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: self.class,
        ref: ref,
        referrer: referrer,
        registry: registry,
      }.freeze
    end

    include(Util::FingerprintHash::Immutable)
  end
end
