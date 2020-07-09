# frozen_string_literal: true

module JSI
  module JSON
    # a representation to work with JSON Pointer, as described by RFC 6901 https://tools.ietf.org/html/rfc6901
    class Pointer
      class Error < StandardError
      end
      class PointerSyntaxError < Error
      end
      class ReferenceError < Error
      end

      # instantiates a Pointer from the given reference tokens.
      #
      #     JSI::JSON::Pointer[]
      #
      # instantes a root pointer.
      #
      #     JSI::JSON::Pointer['a', 'b']
      #     JSI::JSON::Pointer['a']['b']
      #
      # are both ways to instantiate a pointer with reference tokens ['a', 'b']. the latter example chains the
      # class .[] method with the instance #[] method.
      #
      # @param reference_tokens any number of reference tokens
      # @return [JSI::JSON::Pointer]
      def self.[](*reference_tokens)
        new(reference_tokens)
      end

      # parse a URI-escaped fragment and instantiate as a JSI::JSON::Pointer
      #
      #     JSI::JSON::Pointer.from_fragment('/foo/bar')
      #     => JSI::JSON::Pointer["foo", "bar"]
      #
      # with URI escaping:
      #
      #     JSI::JSON::Pointer.from_fragment('/foo%20bar')
      #     => JSI::JSON::Pointer["foo bar"]
      #
      # @param fragment [String] a fragment containing a pointer
      # @return [JSI::JSON::Pointer]
      # @raise [JSI::JSON::Pointer::PointerSyntaxError] when the fragment does not contain a pointer with
      #   valid pointer syntax
      def self.from_fragment(fragment)
        from_pointer(Addressable::URI.unescape(fragment), type: 'fragment')
      end

      # parse a pointer string and instantiate as a JSI::JSON::Pointer
      #
      #     JSI::JSON::Pointer.from_pointer('/foo')
      #     => JSI::JSON::Pointer["foo"]
      #
      #     JSI::JSON::Pointer.from_pointer('/foo~0bar/baz~1qux')
      #     => JSI::JSON::Pointer["foo~bar", "baz/qux"]
      #
      # @param pointer_string [String] a pointer string
      # @param type (for internal use) indicates the original representation of the pointer
      # @return [JSI::JSON::Pointer]
      # @raise [JSI::JSON::Pointer::PointerSyntaxError] when the pointer_string does not have valid pointer syntax
      def self.from_pointer(pointer_string, type: 'pointer')
        tokens = pointer_string.split('/', -1).map! do |piece|
          piece.gsub('~1', '/').gsub('~0', '~')
        end
        if tokens[0] == ''
          new(tokens[1..-1], type: type)
        elsif tokens.empty?
          new(tokens, type: type)
        else
          raise(PointerSyntaxError, "Invalid pointer syntax in #{pointer_string.inspect}: pointer must begin with /")
        end
      end

      # initializes a JSI::JSON::Pointer from the given reference_tokens.
      #
      # @param reference_tokens [Array<Object>]
      # @param type [String, Symbol] one of 'pointer' or 'fragment'
      def initialize(reference_tokens, type: nil)
        unless reference_tokens.respond_to?(:to_ary)
          raise(TypeError, "reference_tokens must be an array. got: #{reference_tokens.inspect}")
        end
        @reference_tokens = reference_tokens.to_ary.map(&:freeze).freeze
        @type = type.is_a?(Symbol) ? type.to_s : type
      end

      attr_reader :reference_tokens

      # takes a root json document and evaluates this pointer through the document, returning the value
      # pointed to by this pointer.
      #
      # @param document [#to_ary, #to_hash] the document against which we will evaluate this pointer
      # @return [Object] the content of the document pointed to by this pointer
      # @raise [JSI::JSON::Pointer::ReferenceError] the document does not contain the path this pointer references
      def evaluate(document)
        res = reference_tokens.inject(document) do |value, token|
          if value.respond_to?(:to_ary)
            if token.is_a?(String) && token =~ /\A\d|[1-9]\d+\z/
              token = token.to_i
            end
            unless token.is_a?(Integer)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not an integer and cannot be resolved in array #{value.inspect}")
            end
            unless (0...(value.respond_to?(:size) ? value : value.to_ary).size).include?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid index of #{value.inspect}")
            end
            (value.respond_to?(:[]) ? value : value.to_ary)[token]
          elsif value.respond_to?(:to_hash)
            unless (value.respond_to?(:key?) ? value : value.to_hash).key?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid key of #{value.inspect}")
            end
            (value.respond_to?(:[]) ? value : value.to_hash)[token]
          else
            raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} cannot be resolved in #{value.inspect}")
          end
        end
        res
      end

      # @return [String] the pointer string representation of this Pointer
      def pointer
        reference_tokens.map { |t| '/' + t.to_s.gsub('~', '~0').gsub('/', '~1') }.join('')
      end

      # @return [String] the fragment string representation of this Pointer
      def fragment
        Addressable::URI.escape(pointer)
      end

      # @return [Addressable::URI] a URI consisting of a fragment containing this pointer's fragment string
      #   representation
      def uri
        Addressable::URI.new(fragment: fragment)
      end

      # @return [Boolean] whether this is a root pointer, indicated by an empty array of reference_tokens
      def root?
        reference_tokens.empty?
      end

      # @return [JSI::JSON::Pointer] pointer to the parent of where this pointer points
      # @raise [JSI::JSON::Pointer::ReferenceError] if this pointer has no parent (points to the root)
      def parent
        if root?
          raise(ReferenceError, "cannot access parent of root pointer: #{pretty_inspect.chomp}")
        else
          Pointer.new(reference_tokens[0...-1], type: @type)
        end
      end

      # @return [Boolean] does this pointer contain the other_ptr - that is, is this pointer an
      #   ancestor of other_ptr, a child pointer. contains? is inclusive; a pointer does contain itself.
      def contains?(other_ptr)
        self.reference_tokens == other_ptr.reference_tokens[0...self.reference_tokens.size]
      end

      # @return [JSI::JSON::Pointer] returns this pointer relative to the given ancestor_ptr
      # @raise [JSI::JSON::Pointer::ReferenceError] if the given ancestor_ptr is not an ancestor of this pointer
      def ptr_relative_to(ancestor_ptr)
        unless ancestor_ptr.contains?(self)
          raise(ReferenceError, "ancestor_ptr #{ancestor_ptr.inspect} is not ancestor of #{inspect}")
        end
        Pointer.new(reference_tokens[ancestor_ptr.reference_tokens.size..-1], type: @type)
      end

      # @param ptr [JSI::JSON::Pointer]
      # @return [JSI::JSON::Pointer] a pointer with the reference tokens of this one plus the given ptr's.
      def +(ptr)
        unless ptr.is_a?(JSI::JSON::Pointer)
          raise(TypeError, "ptr must be a JSI::JSON::Pointer; got: #{ptr.inspect}")
        end
        Pointer.new(reference_tokens + ptr.reference_tokens, type: @type)
      end

      # @param n [Integer]
      # @return [JSI::JSON::Pointer] a Pointer consisting of the first n of our reference_tokens
      # @raise [ArgumentError] if n is not between 0 and the size of our reference_tokens
      def take(n)
        unless (0..reference_tokens.size).include?(n)
          raise(ArgumentError, "n not in range (0..#{reference_tokens.size}): #{n.inspect}")
        end
        Pointer.new(reference_tokens.take(n), type: @type)
      end

      # appends the given token to this Pointer's reference tokens and returns the result
      #
      # @param token [Object]
      # @return [JSI::JSON::Pointer] pointer to a child node of this pointer with the given token
      def [](token)
        Pointer.new(reference_tokens + [token], type: @type)
      end

      # given this Pointer points to a schema in the given document, returns a set of pointers
      # to subschemas of that schema for the given property name.
      #
      # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
      # @param property_name [Object] the property name for which to find a subschema
      # @return [Set<JSI::JSON::Pointer>] pointers to subschemas
      def schema_subschema_ptrs_for_property_name(document, property_name)
        ptr = self
        schema = ptr.evaluate(document)
        Set.new.tap do |ptrs|
          if schema.respond_to?(:to_hash)
            apply_additional = true
            if schema.key?('properties') && schema['properties'].respond_to?(:to_hash) && schema['properties'].key?(property_name)
              apply_additional = false
              ptrs << ptr['properties'][property_name]
            end
            if schema['patternProperties'].respond_to?(:to_hash)
              schema['patternProperties'].each_key do |pattern|
                if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                  apply_additional = false
                  ptrs << ptr['patternProperties'][pattern]
                end
              end
            end
            if apply_additional && schema.key?('additionalProperties')
              ptrs << ptr['additionalProperties']
            end
          end
        end
      end

      # given this Pointer points to a schema in the given document, returns a set of pointers
      # to subschemas of that schema for the given array index.
      #
      # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
      # @param idx [Object] the array index for which to find subschemas
      # @return [Set<JSI::JSON::Pointer>] pointers to subschemas
      def schema_subschema_ptrs_for_index(document, idx)
        ptr = self
        schema = ptr.evaluate(document)
        Set.new.tap do |ptrs|
          if schema.respond_to?(:to_hash)
            if schema['items'].respond_to?(:to_ary)
              if schema['items'].each_index.to_a.include?(idx)
                ptrs << ptr['items'][idx]
              elsif schema.key?('additionalItems')
                ptrs << ptr['additionalItems']
              end
            elsif schema.key?('items')
              ptrs << ptr['items']
            end
          end
        end
      end

      # given this Pointer points to a schema in the given document, this matches any
      # applicators of the schema (oneOf, anyOf, allOf, $ref) which should be applied
      # and returns them as a set of pointers.
      #
      # @param document [#to_hash, #to_ary, Object] document containing the schema this pointer points to
      # @param instance [Object] the instance to check any applicators against
      # @return [JSI::JSON::Pointer] either a pointer to a *Of subschema in the document,
      #   or self if no other subschema was matched
      def schema_match_ptrs_to_instance(document, instance)
        ptr = self
        schema = ptr.evaluate(document)

        Set.new.tap do |ptrs|
          if schema.respond_to?(:to_hash)
            if schema['$ref'].respond_to?(:to_str)
              ptr.deref(document) do |deref_ptr|
                ptrs.merge(deref_ptr.schema_match_ptrs_to_instance(document, instance))
              end
            else
              ptrs << ptr
            end
            if schema['allOf'].respond_to?(:to_ary)
              schema['allOf'].each_index do |i|
                ptrs.merge(ptr['allOf'][i].schema_match_ptrs_to_instance(document, instance))
              end
            end
            if schema['anyOf'].respond_to?(:to_ary)
              schema['anyOf'].each_index do |i|
                valid = ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['anyOf'][i].fragment)
                if valid
                  ptrs.merge(ptr['anyOf'][i].schema_match_ptrs_to_instance(document, instance))
                end
              end
            end
            if schema['oneOf'].respond_to?(:to_ary)
              one_i = schema['oneOf'].each_index.detect do |i|
                ::JSON::Validator.validate(JSI::Typelike.as_json(document), JSI::Typelike.as_json(instance), fragment: ptr['oneOf'][i].fragment)
              end
              if one_i
                ptrs.merge(ptr['oneOf'][one_i].schema_match_ptrs_to_instance(document, instance))
              end
            end
            # TODO dependencies
          else
            ptrs << ptr
          end
        end
      end

      # takes a document and a block. the block is yielded the content of the given document at this
      # pointer's location. the block must result a modified copy of that content (and MUST NOT modify
      # the object it is given). this modified copy of that content is incorporated into a modified copy
      # of the given document, which is then returned. the structure and contents of the document outside
      # the path pointed to by this pointer is not modified.
      #
      # @param document [Object] the document to apply this pointer to
      # @yield [Object] the content this pointer applies to in the given document
      #   the block must result in the new content which will be placed in the modified document copy.
      # @return [Object] a copy of the given document, with the content this pointer applies to
      #   replaced by the result of the block
      def modified_document_copy(document, &block)
        # we need to preserve the rest of the document, but modify the content at our path.
        #
        # this is actually a bit tricky. we can't modify the original document, obviously.
        # we could do a deep copy, but that's expensive. instead, we make a copy of each array
        # or hash in the path above this node. this node's content is modified by the caller, and
        # that is recursively merged up to the document root. the recursion is done with a
        # y combinator, for no other reason than that was a fun way to implement it.
        modified_document = JSI::Util.ycomb do |rec|
          proc do |subdocument, subpath|
            if subpath == []
              Typelike.modified_copy(subdocument, &block)
            else
              car = subpath[0]
              cdr = subpath[1..-1]
              if subdocument.respond_to?(:to_hash)
                subdocument_car = (subdocument.respond_to?(:[]) ? subdocument : subdocument.to_hash)[car]
                car_object = rec.call(subdocument_car, cdr)
                if car_object.object_id == subdocument_car.object_id
                  subdocument
                else
                  (subdocument.respond_to?(:merge) ? subdocument : subdocument.to_hash).merge({car => car_object})
                end
              elsif subdocument.respond_to?(:to_ary)
                if car.is_a?(String) && car =~ /\A\d+\z/
                  car = car.to_i
                end
                unless car.is_a?(Integer)
                  raise(TypeError, "bad subscript #{car.pretty_inspect.chomp} with remaining subpath: #{cdr.inspect} for array: #{subdocument.pretty_inspect.chomp}")
                end
                subdocument_car = (subdocument.respond_to?(:[]) ? subdocument : subdocument.to_ary)[car]
                car_object = rec.call(subdocument_car, cdr)
                if car_object.object_id == subdocument_car.object_id
                  subdocument
                else
                  (subdocument.respond_to?(:[]=) ? subdocument : subdocument.to_ary).dup.tap do |arr|
                    arr[car] = car_object
                  end
                end
              else
                raise(TypeError, "bad subscript: #{car.pretty_inspect.chomp} with remaining subpath: #{cdr.inspect} for content: #{subdocument.pretty_inspect.chomp}")
              end
            end
          end
        end.call(document, reference_tokens)
        modified_document
      end

      # if this Pointer points at a $ref node within the given document, #deref attempts
      # to follow that $ref and return a Pointer to the referenced location. otherwise,
      # this Pointer is returned.
      #
      # if the content this Pointer points to in the document is not hash-like, does not
      # have a $ref property, its $ref cannot be found, or its $ref points outside the document,
      # this pointer is returned.
      #
      # @param document [Object] the document this pointer applies to
      # @yield [Pointer] if a block is given (optional), this will yield a deref'd pointer. if this
      #   pointer does not point to a $ref object in the given document, the block is not called.
      #   if we point to a $ref which cannot be followed (e.g. a $ref to an external
      #   document, which is not yet supported), the block is not called.
      # @return [Pointer] dereferenced pointer, or this pointer
      def deref(document, &block)
        block ||= Util::NOOP
        content = evaluate(document)

        if content.respond_to?(:to_hash)
          ref = (content.respond_to?(:[]) ? content : content.to_hash)['$ref']
        end
        return self unless ref.is_a?(String)

        if ref[/\A#/]
          return Pointer.from_fragment(Addressable::URI.parse(ref).fragment).tap(&block)
        end

        # HAX for how google does refs and ids
        if document['schemas'].respond_to?(:to_hash)
          if document['schemas'][ref]
            return Pointer.new(['schemas', ref], type: 'hax').tap(&block)
          end
          document['schemas'].each do |k, schema|
            if schema['id'] == ref
              return Pointer.new(['schemas', k], type: 'hax').tap(&block)
            end
          end
        end

        #raise(NotImplementedError, "cannot dereference #{ref}") # TODO
        return self
      end

      # @return [String] a string representation of this Pointer
      def inspect
        "#{self.class.name}[#{reference_tokens.map(&:inspect).join(", ")}]"
      end

      alias_method :to_s, :inspect

      # pointers are equal if the reference_tokens are equal, regardless of @type
      def jsi_fingerprint
        {class: JSI::JSON::Pointer, reference_tokens: reference_tokens}
      end
      include Util::FingerprintHash
    end
  end
end
