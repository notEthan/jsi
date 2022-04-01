# frozen_string_literal: true

module JSI
  # JSI::Schema::Ref is a reference to another schema (the result of #deref_schema), resolved using a ref URI
  # from a ref schema (the ref URI typically the contents of the ref_schema's "$ref" keyword)
  class Schema::Ref
    # @param ref [String] a reference URI
    # @param ref_schema [JSI::Schema] a schema from which the reference originated
    def initialize(ref, ref_schema = nil)
      raise(ArgumentError, "ref is not a string") unless ref.respond_to?(:to_str)
      @ref = ref
      @ref_uri = Util.uri(ref)
      @ref_schema = ref_schema ? Schema.ensure_schema(ref_schema) : nil
    end

    attr_reader :ref

    attr_reader :ref_uri

    attr_reader :ref_schema

    # finds the schema this ref points to
    # @return [JSI::Schema]
    # @raise [JSI::Schema::NotASchemaError] when the thing this ref points to is not a schema
    # @raise [JSI::Schema::ReferenceError] when this reference cannot be resolved
    def deref_schema
      return @deref_schema if instance_variable_defined?(:@deref_schema)

      schema_resource_root = nil
      check_schema_resource_root = -> {
        unless schema_resource_root
          raise(Schema::ReferenceError, [
            "cannot find schema by ref: #{ref}",
            ("from: #{ref_schema.pretty_inspect.chomp}" if ref_schema),
          ].compact.join("\n"))
        end
      }

      ref_uri_nofrag = ref_uri.merge(fragment: nil).freeze

      if ref_uri_nofrag.empty?
        unless ref_schema
          raise(Schema::ReferenceError, [
            "cannot find schema by ref: #{ref}",
            "with no ref schema",
          ].join("\n"))
        end

        # the URI only consists of a fragment (or is empty).
        # for a fragment pointer, resolve using Schema#resource_root_subschema on the ref_schema.
        # for a fragment anchor, bootstrap does not support anchors; otherwise use the ref_schema's schema_resource_root.
        schema_resource_root = ref_schema.is_a?(MetaschemaNode::BootstrapSchema) ? nil : ref_schema.schema_resource_root
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
          schema_resource_root = JSI.schema_registry.find(ref_abs_uri)
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
          raise(Schema::ReferenceError, [
            "could not resolve pointer: #{ptr_from_fragment.pointer.inspect}",
            ("from: #{ref_schema.pretty_inspect.chomp}" if ref_schema),
            ("in schema resource root: #{schema_resource_root.pretty_inspect.chomp}" if schema_resource_root),
          ].compact.join("\n"))
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
          raise(Schema::ReferenceError, [
            "could not find schema by fragment: #{fragment.inspect}",
            "in schema resource root: #{schema_resource_root.pretty_inspect.chomp}",
          ].join("\n"))
        else
          raise(Schema::ReferenceError, [
            "found multiple schemas for plain name fragment #{fragment.inspect}:",
            *result_schemas.map { |s| s.pretty_inspect.chomp },
          ].join("\n"))
        end
      end

      Schema.ensure_schema(result_schema, msg: "object identified by uri #{ref} is not a schema:")
      return @deref_schema = result_schema
    end

    # @return [String]
    def inspect
      %Q(\#<#{self.class.name} #{ref}>)
    end

    alias_method :to_s, :inspect

    # pretty-prints a representation of self to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text self.class.name
      q.text ' '
      q.text ref
      q.text '>'
    end

    # @private
    def jsi_fingerprint
      {class: self.class, ref: ref, ref_schema: ref_schema}
    end
    include Util::FingerprintHash
  end
end
