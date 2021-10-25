# frozen_string_literal: true

module JSI
    # a representation to work with JSON Pointer, as described by RFC 6901 https://tools.ietf.org/html/rfc6901
    #
    # a pointer is a sequence of tokens pointing to a node in a document.
    class Ptr
      class Error < StandardError
      end

      # raised when attempting to parse a JSON Pointer string with invalid syntax
      class PointerSyntaxError < Error
      end

      # raised when a pointer refers to a path in a document that could not be resolved
      class ResolutionError < Error
      end

      # @param ary_ptr [#to_ary, JSI::Ptr] an array of tokens, or a pointer
      # @return [JSI::Ptr] a pointer with the given tokens, or the given pointer
      def self.ary_ptr(ary_ptr)
        if ary_ptr.is_a?(Ptr)
          ary_ptr
        else
          new(ary_ptr)
        end
      end

      # instantiates a pointer from the given tokens.
      #
      #     JSI::Ptr[]
      #
      # instantes a root pointer.
      #
      #     JSI::Ptr['a', 'b']
      #     JSI::Ptr['a']['b']
      #
      # are both ways to instantiate a pointer with tokens ['a', 'b']. the latter example chains the
      # class .[] method with the instance #[] method.
      #
      # @param tokens any number of tokens
      # @return [JSI::Ptr]
      def self.[](*tokens)
        new(tokens)
      end

      # parse a URI-escaped fragment and instantiate as a JSI::Ptr
      #
      #     JSI::Ptr.from_fragment('/foo/bar')
      #     => JSI::Ptr["foo", "bar"]
      #
      # with URI escaping:
      #
      #     JSI::Ptr.from_fragment('/foo%20bar')
      #     => JSI::Ptr["foo bar"]
      #
      # @param fragment [String] a fragment containing a pointer
      # @return [JSI::Ptr]
      # @raise [JSI::Ptr::PointerSyntaxError] when the fragment does not contain a pointer with
      #   valid pointer syntax
      def self.from_fragment(fragment)
        from_pointer(Addressable::URI.unescape(fragment))
      end

      # parse a pointer string and instantiate as a JSI::Ptr
      #
      #     JSI::Ptr.from_pointer('/foo')
      #     => JSI::Ptr["foo"]
      #
      #     JSI::Ptr.from_pointer('/foo~0bar/baz~1qux')
      #     => JSI::Ptr["foo~bar", "baz/qux"]
      #
      # @param pointer_string [String] a pointer string
      # @return [JSI::Ptr]
      # @raise [JSI::Ptr::PointerSyntaxError] when the pointer_string does not have valid pointer syntax
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

      # initializes a JSI::Ptr from the given tokens.
      #
      # @param tokens [Array<Object>]
      def initialize(tokens)
        unless tokens.respond_to?(:to_ary)
          raise(TypeError, "tokens must be an array. got: #{tokens.inspect}")
        end
        @tokens = tokens.to_ary.map(&:freeze).freeze
      end

      attr_reader :tokens

      # @private @deprecated
      alias_method :reference_tokens, :tokens

      # takes a root json document and evaluates this pointer through the document, returning the value
      # pointed to by this pointer.
      #
      # @param document [#to_ary, #to_hash] the document against which we will evaluate this pointer
      # @param a arguments are passed to each invocation of `#[]`
      # @return [Object] the content of the document pointed to by this pointer
      # @raise [JSI::Ptr::ResolutionError] the document does not contain the path this pointer references
      def evaluate(document, *a)
        res = tokens.inject(document) do |value, token|
          _, child = node_subscript_token_child(value, token, *a)
          child
        end
        res
      end

      # @return [String] the pointer string representation of this pointer
      def pointer
        tokens.map { |t| '/' + t.to_s.gsub('~', '~0').gsub('/', '~1') }.join('')
      end

      # @return [String] the fragment string representation of this pointer
      def fragment
        Addressable::URI.escape(pointer)
      end

      # @return [Addressable::URI] a URI consisting of a fragment containing this pointer's fragment string
      #   representation
      def uri
        Addressable::URI.new(fragment: fragment)
      end

      # @return [Boolean] whether this pointer is empty, i.e. it has no tokens
      def empty?
        tokens.empty?
      end

      # @return [Boolean] whether this is a root pointer, indicated by an empty array of tokens
      alias_method :root?, :empty?

      # @return [JSI::Ptr] pointer to the parent of where this pointer points
      # @raise [JSI::Ptr::Error] if this pointer has no parent (points to the root)
      def parent
        if root?
          raise(Ptr::Error, "cannot access parent of root pointer: #{pretty_inspect.chomp}")
        else
          Ptr.new(tokens[0...-1])
        end
      end

      # @return [Boolean] does this pointer contain the other_ptr - that is, is this pointer an
      #   ancestor of other_ptr, a child pointer. contains? is inclusive; a pointer does contain itself.
      def contains?(other_ptr)
        self.tokens == other_ptr.tokens[0...self.tokens.size]
      end

      # @return [JSI::Ptr] part of this pointer relative to the given ancestor_ptr
      # @raise [JSI::Ptr::Error] if the given ancestor_ptr is not an ancestor of this pointer
      def ptr_relative_to(ancestor_ptr)
        unless ancestor_ptr.contains?(self)
          raise(Error, "ancestor_ptr #{ancestor_ptr.inspect} is not ancestor of #{inspect}")
        end
        Ptr.new(tokens[ancestor_ptr.tokens.size..-1])
      end

      # @param ptr [JSI::Ptr, #to_ary]
      # @return [JSI::Ptr] a pointer with the tokens of this one plus the given ptr's.
      def +(ptr)
        if ptr.is_a?(Ptr)
          ptr_tokens = ptr.tokens
        elsif ptr.respond_to?(:to_ary)
          ptr_tokens = ptr
        else
          raise(TypeError, "ptr must be a JSI::Ptr or Array of tokens; got: #{ptr.inspect}")
        end
        Ptr.new(self.tokens + ptr_tokens)
      end

      # @param n [Integer]
      # @return [JSI::Ptr] a pointer consisting of the first n of our tokens
      # @raise [ArgumentError] if n is not between 0 and the size of our tokens
      def take(n)
        unless (0..tokens.size).include?(n)
          raise(ArgumentError, "n not in range (0..#{tokens.size}): #{n.inspect}")
        end
        Ptr.new(tokens.take(n))
      end

      # appends the given token to this pointer's tokens and returns the result
      #
      # @param token [Object]
      # @return [JSI::Ptr] pointer to a child node of this pointer with the given token
      def [](token)
        Ptr.new(tokens + [token])
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
        # or hash in the path above the node we point to. this node's content is modified by the
        # caller, and that is recursively merged up to the document root.
        if empty?
          Typelike.modified_copy(document, &block)
        else
          car = tokens[0]
          cdr = Ptr.new(tokens[1..-1])
          token, document_child = node_subscript_token_child(document, car)
          modified_document_child = cdr.modified_document_copy(document_child, &block)
          if modified_document_child.object_id == document_child.object_id
            document
          else
            modified_document = document.respond_to?(:[]=) ? document.dup :
              document.respond_to?(:to_hash) ? document.to_hash.dup :
              document_child.respond_to?(:to_ary) ? document.to_ary.dup :
              raise(Bug) # not possible; node_subscript_token_child would have raised
            modified_document[token] = modified_document_child
            modified_document
          end
        end
      end

      # @return [String] a string representation of this pointer
      def inspect
        "#{self.class.name}[#{tokens.map(&:inspect).join(", ")}]"
      end

      alias_method :to_s, :inspect

      # pointers are equal if the tokens are equal
      def jsi_fingerprint
        {class: Ptr, tokens: tokens}
      end
      include Util::FingerprintHash

      private

      def node_subscript_token_child(value, token, *a)
        if value.respond_to?(:to_ary)
          if token.is_a?(String) && token =~ /\A\d|[1-9]\d+\z/
            token = token.to_i
          elsif token == '-'
            # per rfc6901, - refers "to the (nonexistent) member after the last array element" and is
            # expected to raise an error condition.
            raise(ResolutionError, "Invalid resolution: #{token.inspect} refers to a nonexistent element in array #{value.inspect}")
          end
          unless token.is_a?(Integer)
            raise(ResolutionError, "Invalid resolution: #{token.inspect} is not an integer and cannot be resolved in array #{value.inspect}")
          end
          unless (0...(value.respond_to?(:size) ? value : value.to_ary).size).include?(token)
            raise(ResolutionError, "Invalid resolution: #{token.inspect} is not a valid index of #{value.inspect}")
          end

          child = (value.respond_to?(:[]) ? value : value.to_ary)[token, *a]
        elsif value.respond_to?(:to_hash)
          unless (value.respond_to?(:key?) ? value : value.to_hash).key?(token)
            raise(ResolutionError, "Invalid resolution: #{token.inspect} is not a valid key of #{value.inspect}")
          end

          child = (value.respond_to?(:[]) ? value : value.to_hash)[token, *a]
        else
          raise(ResolutionError, "Invalid resolution: #{token.inspect} cannot be resolved in #{value.inspect}")
        end
        [token, child]
      end
    end
end
