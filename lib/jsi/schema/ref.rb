# frozen_string_literal: true

module JSI
  # A JSI::Schema::Ref is a reference to a schema identified by a URI, typically from
  # a `$ref` keyword of a schema.
  class Schema::Ref
    # @param ref [String] A reference URI - typically the `$ref` value of the ref_schema
    # @param ref_schema [JSI::Schema] A schema from which the reference originated.
    #
    #   If the ref URI consists of only a fragment, it is resolved from the `ref_schema`'s
    #   {Schema#schema_resource_root}. Otherwise the resource is found in the `ref_schema`'s
    #   {SchemaAncestorNode#jsi_schema_registry #jsi_schema_registry} (and any fragment is resolved from there).
    # @param schema_registry [SchemaRegistry] The registry in which the resource this ref refers to will be found.
    #   This should only be specified in the absence of a `ref_schema`.
    #   If neither is specified, {JSI.schema_registry} is used.
    def initialize(ref, ref_schema: nil, schema_registry: nil)
      raise(ArgumentError, "ref is not a string") unless ref.respond_to?(:to_str)
      @ref = ref
      @ref_uri = Util.uri(ref)
      @ref_schema = ref_schema ? Schema.ensure_schema(ref_schema) : nil
      @schema_registry = schema_registry || (ref_schema ? ref_schema.jsi_schema_registry : JSI.schema_registry)
      @deref_schema = nil
    end

    # @return [String]
    attr_reader :ref

    # @return [Addressable::URI]
    attr_reader :ref_uri

    # @return [Schema, nil]
    attr_reader :ref_schema

    # @return [SchemaRegistry, nil]
    attr_reader(:schema_registry)

    # finds the schema this ref points to
    # @return [JSI::Schema]
    # @raise [JSI::Schema::NotASchemaError] when the thing this ref points to is not a schema
    # @raise [ResolutionError] when this reference cannot be resolved
    def deref_schema
      return @deref_schema if @deref_schema

      schema_resource_root = nil
      check_schema_resource_root = -> {
        unless schema_resource_root
          raise(ResolutionError.new([
            "cannot find schema by ref: #{ref}",
            ("from: #{ref_schema.pretty_inspect.chomp}" if ref_schema),
          ], uri: ref_uri))
        end
      }

      ref_uri_nofrag = ref_uri.merge(fragment: nil).freeze

      if ref_uri_nofrag.empty?
        unless ref_schema
          raise(ResolutionError.new([
            "cannot find schema by ref: #{ref}",
            "with no ref schema",
          ], uri: ref_uri))
        end

        # the URI only consists of a fragment (or is empty).
        # for a fragment pointer, resolve using Schema#resource_root_subschema on the ref_schema.
        # for a fragment anchor, bootstrap does not support anchors; otherwise use the ref_schema's schema_resource_root.
        schema_resource_root = ref_schema.is_a?(MetaSchemaNode::BootstrapSchema) ? nil : ref_schema.schema_resource_root
        resolve_fragment_ptr = ref_schema.method(:resource_root_subschema)
      else
        # find the schema_resource_root from the non-fragment URI. we will resolve any fragment, either pointer or anchor, from there.

        if ref_uri_nofrag.absolute?
          ref_abs_uri = ref_uri_nofrag
        elsif ref_schema && ref_schema.jsi_resource_ancestor_uri
          ref_abs_uri = ref_schema.jsi_resource_ancestor_uri.join(ref_uri_nofrag).freeze
        else
          ref_abs_uri = nil
        end
        if ref_abs_uri
          unless schema_registry
            raise(ResolutionError.new([
              "could not resolve remote ref with no schema_registry specified",
              "ref URI: #{ref_uri.to_s}",
              ("from: #{ref_schema.pretty_inspect.chomp}" if ref_schema),
            ], uri: ref_uri))
          end
          schema_resource_root = schema_registry.find(ref_abs_uri)
        end

        unless schema_resource_root
          # HAX for how google does refs and ids
          if ref_schema && ref_schema.jsi_document.respond_to?(:to_hash) && ref_schema.jsi_document['schemas'].respond_to?(:to_hash)
            ref_schema.jsi_document['schemas'].each do |k, v|
              if Addressable::URI.parse(v['id']) == ref_uri_nofrag
                schema_resource_root = ref_schema.resource_root_subschema(['schemas', k])
              end
            end
          end
        end

        check_schema_resource_root.call

        if schema_resource_root.is_a?(Schema)
          resolve_fragment_ptr = schema_resource_root.method(:resource_root_subschema)
        else
          # Note: Schema#resource_root_subschema will reinstantiate nonschemas as schemas.
          # not implemented for remote refs when the schema_resource_root is not a schema.
          resolve_fragment_ptr = -> (ptr) { schema_resource_root.jsi_descendent_node(ptr) }
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
          result_schema = resolve_fragment_ptr.call(ptr_from_fragment)
        rescue Ptr::ResolutionError
          raise(ResolutionError.new([
            "could not resolve pointer: #{ptr_from_fragment.pointer.inspect}",
            ("from: #{ref_schema.pretty_inspect.chomp}" if ref_schema),
            ("in schema resource root: #{schema_resource_root.pretty_inspect.chomp}" if schema_resource_root),
          ], uri: ref_uri))
        end
      elsif fragment.nil?
        check_schema_resource_root.call
        result_schema = schema_resource_root
      else
        check_schema_resource_root.call

        # find an anchor that resembles the fragment
        result_schemas = schema_resource_root.jsi_anchor_subschemas(fragment)

        if result_schemas.size == 1
          result_schema = result_schemas.first
        elsif result_schemas.size == 0
          raise(Schema::ReferenceError.new([
            "could not find schema by fragment: #{fragment.inspect}",
            "in schema resource root: #{schema_resource_root.pretty_inspect.chomp}",
          ], uri: ref_uri))
        else
          raise(Schema::ReferenceError.new([
            "found multiple schemas for plain name fragment #{fragment.inspect}:",
            *result_schemas.map { |s| s.pretty_inspect.chomp },
          ], uri: ref_uri))
        end
      end

      Schema.ensure_schema(result_schema) { "object identified by uri #{ref} is not a schema:" }
      return @deref_schema = result_schema
    end

    # @return [String]
    def inspect
      -%Q(\#<#{self.class.name} #{ref}>)
    end

    def to_s
      inspect
    end

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text self.class.name
      q.text ' '
      q.text ref
      q.text '>'
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {class: self.class, ref: ref, ref_schema: ref_schema}.freeze
    end

    include(Util::FingerprintHash::Immutable)
  end
end
