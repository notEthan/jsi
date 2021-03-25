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

      # @param ary_ptr [#to_ary, JSI::JSON::Pointer] an array of reference tokens, or a pointer
      # @return [JSI::JSON::Pointer] a pointer with the given reference tokens, or the given pointer
      def self.ary_ptr(ary_ptr)
        if ary_ptr.is_a?(Pointer)
          ary_ptr
        else
          new(ary_ptr)
        end
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
        from_pointer(Addressable::URI.unescape(fragment))
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
      # @return [JSI::JSON::Pointer]
      # @raise [JSI::JSON::Pointer::PointerSyntaxError] when the pointer_string does not have valid pointer syntax
      def self.from_pointer(pointer_string)
        tokens = pointer_string.split('/', -1).map! do |piece|
          piece.gsub('~1', '/').gsub('~0', '~')
        end
        if tokens[0] == ''
          new(tokens[1..-1])
        elsif tokens.empty?
          new(tokens)
        else
          raise(PointerSyntaxError, "Invalid pointer syntax in #{pointer_string.inspect}: pointer must begin with /")
        end
      end

      # initializes a JSI::JSON::Pointer from the given reference_tokens.
      #
      # @param reference_tokens [Array<Object>]
      def initialize(reference_tokens)
        unless reference_tokens.respond_to?(:to_ary)
          raise(TypeError, "reference_tokens must be an array. got: #{reference_tokens.inspect}")
        end
        @reference_tokens = reference_tokens.to_ary.map(&:freeze).freeze
      end

      attr_reader :reference_tokens

      # takes a root json document and evaluates this pointer through the document, returning the value
      # pointed to by this pointer.
      #
      # @param document [#to_ary, #to_hash] the document against which we will evaluate this pointer
      # @param a arguments are passed to each invocation of `#[]`
      # @return [Object] the content of the document pointed to by this pointer
      # @raise [JSI::JSON::Pointer::ReferenceError] the document does not contain the path this pointer references
      def evaluate(document, *a)
        res = reference_tokens.inject(document) do |value, token|
          if value.respond_to?(:to_ary)
            if token.is_a?(String) && token =~ /\A\d|[1-9]\d+\z/
              token = token.to_i
            elsif token == '-'
              # per rfc6901, - refers "to the (nonexistent) member after the last array element" and is
              # expected to raise an error condition.
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} refers to a nonexistent element in array #{value.inspect}")
            end
            unless token.is_a?(Integer)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not an integer and cannot be resolved in array #{value.inspect}")
            end
            unless (0...(value.respond_to?(:size) ? value : value.to_ary).size).include?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid index of #{value.inspect}")
            end

            (value.respond_to?(:[]) ? value : value.to_ary)[token, *a]
          elsif value.respond_to?(:to_hash)
            unless (value.respond_to?(:key?) ? value : value.to_hash).key?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid key of #{value.inspect}")
            end

            (value.respond_to?(:[]) ? value : value.to_hash)[token, *a]
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

      # @return [Boolean] whether this pointer is empty, i.e. it has no reference tokens
      def empty?
        reference_tokens.empty?
      end

      # @return [Boolean] whether this is a root pointer, indicated by an empty array of reference_tokens
      alias_method :root?, :empty?

      # @return [JSI::JSON::Pointer] pointer to the parent of where this pointer points
      # @raise [JSI::JSON::Pointer::ReferenceError] if this pointer has no parent (points to the root)
      def parent
        if root?
          raise(ReferenceError, "cannot access parent of root pointer: #{pretty_inspect.chomp}")
        else
          Pointer.new(reference_tokens[0...-1])
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
        Pointer.new(reference_tokens[ancestor_ptr.reference_tokens.size..-1])
      end

      # @param ptr [JSI::JSON::Pointer, #to_ary]
      # @return [JSI::JSON::Pointer] a pointer with the reference tokens of this one plus the given ptr's.
      def +(ptr)
        if ptr.is_a?(JSI::JSON::Pointer)
          ptr_reference_tokens = ptr.reference_tokens
        elsif ptr.respond_to?(:to_ary)
          ptr_reference_tokens = ptr
        else
          raise(TypeError, "ptr must be a JSI::JSON::Pointer or Array of reference_tokens; got: #{ptr.inspect}")
        end
        Pointer.new(self.reference_tokens + ptr_reference_tokens)
      end

      # @param n [Integer]
      # @return [JSI::JSON::Pointer] a Pointer consisting of the first n of our reference_tokens
      # @raise [ArgumentError] if n is not between 0 and the size of our reference_tokens
      def take(n)
        unless (0..reference_tokens.size).include?(n)
          raise(ArgumentError, "n not in range (0..#{reference_tokens.size}): #{n.inspect}")
        end
        Pointer.new(reference_tokens.take(n))
      end

      # appends the given token to this Pointer's reference tokens and returns the result
      #
      # @param token [Object]
      # @return [JSI::JSON::Pointer] pointer to a child node of this pointer with the given token
      def [](token)
        Pointer.new(reference_tokens + [token])
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

      # @return [String] a string representation of this Pointer
      def inspect
        "#{self.class.name}[#{reference_tokens.map(&:inspect).join(", ")}]"
      end

      alias_method :to_s, :inspect

      # pointers are equal if the reference_tokens are equal
      def jsi_fingerprint
        {class: JSI::JSON::Pointer, reference_tokens: reference_tokens}
      end
      include Util::FingerprintHash
    end
  end
end
