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
      @ref_uri = Addressable::URI.parse(ref)
      @ref_schema = ref_schema ? Schema.ensure_schema(ref_schema) : nil
    end

    attr_reader :ref

    attr_reader :ref_uri

    attr_reader :ref_schema

    # @return [JSI::Schema] the schema this ref points to
    # @raise [JSI::Schema::NotASchemaError] when the thing this ref points to is not a schema
    # @raise [JSI::Schema::ReferenceError] when this reference cannot be resolved
    def deref_schema
      return @deref_schema if instance_variable_defined?(:@deref_schema)

      schema_resource_root = nil
      check_schema_resource_root = -> {
        unless schema_resource_root
          raise(Schema::ReferenceError, [
            "cannot find schema by ref: #{ref}",
            "from schema: #{ref_schema.pretty_inspect.chomp}",
          ].join("\n"))
        end
      }

      ref_uri_nofrag = ref_uri.merge(fragment: nil)

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
        schema_resource_root = nil

        if ref_uri_nofrag.absolute?
          ref_abs_uri = ref_uri_nofrag
        elsif ref_schema && ref_schema.jsi_subschema_base_uri && ref_schema.jsi_subschema_base_uri.absolute? # TODO the last check is redundant unless jsi_subschema_base_uri may be relative
          ref_abs_uri = ref_schema.jsi_subschema_base_uri.join(ref_uri_nofrag)
        else
          ref_abs_uri = nil
        end
        if ref_abs_uri
          schema_resource_root = JSI.schema_registry.find(ref_abs_uri)
        end

        unless schema_resource_root
          # HAX for how google does refs and ids
          if ref_schema && ref_schema.jsi_document.respond_to?(:to_hash) && ref_schema.jsi_document['schemas'].respond_to?(:to_hash)
            ref_schema.jsi_document['schemas'].each_key do |k|
              if Addressable::URI.parse(ref_schema.jsi_document['schemas'][k]['id']) == ref_uri_nofrag
                schema_resource_root = ref_schema.resource_root_subschema(['schemas', k])
              end
            end
          end
        end

        check_schema_resource_root.call

        if schema_resource_root.is_a?(Schema)
          resolve_fragment_ptr = schema_resource_root.method(:resource_root_subschema)
        else
          # Note: reinstantiate_nonschemas_as_schemas, implemented in Schema#resource_root_subschema, is not
          # implemented for remote refs when the schema_resource_root is not a schema.
          resolve_fragment_ptr = -> (ptr) { ptr.evaluate(schema_resource_root) }
        end
      end

      fragment = ref_uri.fragment

      if fragment
        begin
          ptr_from_fragment = JSI::JSON::Pointer.from_fragment(fragment)
        rescue JSI::JSON::Pointer::PointerSyntaxError
        end
      end

      if ptr_from_fragment
        result_schema = resolve_fragment_ptr.call(ptr_from_fragment)
      elsif fragment.nil?
        check_schema_resource_root.call
        result_schema = schema_resource_root
      else
        # TODO find an anchor that resembles the fragment
        raise(Schema::ReferenceError, "cannot find schema by fragment: #{fragment} from ref schema: #{ref_schema.pretty_inspect.chomp}")
      end

      Schema.ensure_schema(result_schema, msg: "object identified by uri #{ref} is not a schema:")
      return @deref_schema = result_schema
    end

    # @return [String]
    def inspect
      %Q(\#<#{self.class.name} #{ref}>)
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

    # @private
    def jsi_fingerprint
      {class: self.class, ref: ref, ref_schema: ref_schema}
    end
    include Util::FingerprintHash
  end
end
