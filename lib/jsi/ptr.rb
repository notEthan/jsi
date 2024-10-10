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
      class ResolutionError < JSI::ResolutionError
      end

      POS_INT_RE = /\A[1-9]\d*\z/
      private_constant :POS_INT_RE

      # instantiates a pointer or returns the given pointer
      # @param ary_ptr [#to_ary, JSI::Ptr] an array of tokens, or a pointer
      # @return [JSI::Ptr]
      def self.ary_ptr(ary_ptr)
        if ary_ptr.is_a?(Ptr)
          ary_ptr
        elsif ary_ptr == Util::EMPTY_ARY
          EMPTY
        else
          new(ary_ptr)
        end
      end

      # instantiates a pointer from the given tokens.
      #
      #     JSI::Ptr[]
      #
      # instantiates a root pointer.
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
        tokens.empty? ? EMPTY : new(tokens.freeze)
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
      # Note: A fragment does not include a leading '#'. The string "#/foo" is a URI containing the
      # fragment "/foo", which should be parsed by `JSI::URI` before passing to this method, e.g.:
      #
      #     JSI::Ptr.from_fragment(JSI::URI.parse("#/foo").fragment)
      #     => JSI::Ptr["foo"]
      #
      # @param fragment [String] a fragment containing a pointer
      # @return [JSI::Ptr]
      # @raise [JSI::Ptr::PointerSyntaxError] when the fragment does not contain a pointer with
      #   valid pointer syntax
      def self.from_fragment(fragment)
        from_pointer(URI.unescape(fragment))
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
        pointer_string = pointer_string.to_str
        if pointer_string[0] == ?/
          tokens = pointer_string.split('/', -1).map! do |piece|
            piece.gsub!('~1', '/')
            piece.gsub!('~0', '~')
            piece.freeze
          end
          tokens.shift
          new(tokens.freeze)
        elsif pointer_string.empty?
          EMPTY
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
        @tokens = Util.deep_to_frozen(tokens.to_ary, not_implemented: proc { |o| o })
      end

      attr_reader :tokens

      # takes a root json document and evaluates this pointer through the document, returning the value
      # pointed to by this pointer.
      #
      # @param document [#to_ary, #to_hash] the document against which we will evaluate this pointer
      # @param a arguments are passed to each invocation of `#[]`
      # @return [Object] the content of the document pointed to by this pointer
      # @raise [JSI::Ptr::ResolutionError] the document does not contain the path this pointer references
      def evaluate(document, *a, **kw)
        res = tokens.inject(document) do |value, token|
          _, child = node_subscript_token_child(value, token, *a, **kw)
          child
        end
        res
      end

      # Resolves each token of this pointer in `document`, in particular resolving strings indicating
      # array indices to integers.
      # @param document [Object]
      # @return [Ptr]
      def resolve_against(document)
        return(self) if tokens.empty?
        node = document
        resolved_tokens = Array.new(tokens.size)
        tokens.each_with_index do |token, i|
          resolved_token, node = node_subscript_token_child(node, token)
          resolved_tokens[i] = resolved_token
        end
        Ptr.new(resolved_tokens.freeze)
      end

      # the pointer string representation of this pointer
      # @return [String]
      def pointer
        tokens.map { |t| '/' + t.to_s.gsub('~', '~0').gsub('/', '~1') }.join('').freeze
      end

      # the fragment string representation of this pointer
      # @return [String]
      def fragment
        URI.escape(pointer).freeze
      end

      # a URI consisting of a fragment containing this pointer's fragment string representation
      # @return [URI]
      def uri
        URI.new(fragment: fragment).freeze
      end

      # whether this pointer is empty, i.e. it has no tokens
      # @return [Boolean]
      def empty?
        tokens.empty?
      end

      # whether this is a root pointer, indicated by an empty array of tokens
      # @return [Boolean]
      alias_method :root?, :empty?

      # pointer to the parent of where this pointer points
      # @return [JSI::Ptr]
      # @raise [JSI::Ptr::Error] if this pointer has no parent (points to the root)
      def parent
        if root?
          raise(Ptr::Error, "cannot access parent of root pointer: #{pretty_inspect.chomp}")
        end
        tokens.size == 1 ? EMPTY : Ptr.new(tokens[0...-1].freeze)
      end

      # whether this pointer is an ancestor of `other_ptr`, a descendent pointer.
      # `ancestor_of?` is inclusive; a pointer is an ancestor of itself.
      #
      # @return [Boolean]
      def ancestor_of?(other_ptr)
        tokens == other_ptr.tokens[0...tokens.size]
      end

      # part of this pointer relative to the given ancestor_ptr
      # @return [JSI::Ptr]
      # @raise [JSI::Ptr::Error] if the given ancestor_ptr is not an ancestor of this pointer
      def relative_to(ancestor_ptr)
        return self if ancestor_ptr.empty?
        unless ancestor_ptr.ancestor_of?(self)
          raise(Error, "ancestor_ptr #{ancestor_ptr.inspect} is not ancestor of #{inspect}")
        end
        ancestor_ptr.tokens.size == tokens.size ? EMPTY : Ptr.new(tokens[ancestor_ptr.tokens.size..-1].freeze)
      end

      # a pointer with the tokens of this one plus the given `ptr`'s.
      # @param ptr [JSI::Ptr, #to_ary]
      # @return [JSI::Ptr]
      def +(ptr)
        if ptr.is_a?(Ptr)
          return(ptr) if tokens.empty?
          ptr_tokens = ptr.tokens
        elsif ptr.respond_to?(:to_ary)
          ptr_tokens = ptr
        else
          raise(TypeError, "ptr must be a #{Ptr} or Array of tokens; got: #{ptr.inspect}")
        end
        ptr_tokens.empty? ? self : Ptr.new((tokens + ptr_tokens).freeze)
      end

      # a pointer consisting of the first `n` of our tokens
      # @param n [Integer]
      # @return [JSI::Ptr]
      # @raise [ArgumentError] if n is not between 0 and the size of our tokens
      def take(n)
        return(EMPTY) if n == 0
        return(self) if n == tokens.size
        unless n.is_a?(Integer) && n >= 0 && n <= tokens.size
          raise(ArgumentError, "n not in range (0..#{tokens.size}): #{n.inspect}")
        end
        Ptr.new(tokens.take(n).freeze)
      end

      # appends the given token to this pointer's tokens and returns the result
      #
      # @param token [Object]
      # @return [JSI::Ptr] pointer to a child node of this pointer with the given token
      def [](token)
        Ptr.new(tokens.dup.push(token).freeze)
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
          Util.modified_copy(document, &block)
        else
          car = tokens[0]
          cdr = tokens.size == 1 ? EMPTY : Ptr.new(tokens[1..-1].freeze)
          token, document_child = node_subscript_token_child(document, car)
          modified_document_child = cdr.modified_document_copy(document_child, &block)
          if modified_document_child.object_id == document_child.object_id
            document
          else
            modified_document = document.respond_to?(:[]=) ? document.dup :
              document.respond_to?(:to_hash) ? document.to_hash.dup :
              document.respond_to?(:to_ary) ? document.to_ary.dup :
              fail(Bug) # not possible; node_subscript_token_child would have raised
            modified_document[token] = modified_document_child
            modified_document
          end
        end
      end

      # a string representation of this pointer
      # @return [String]
      def inspect
        -"#{self.class.name}[#{tokens.map(&:inspect).join(", ")}]"
      end

      def to_s
        inspect
      end

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {class: Ptr, tokens: tokens}.freeze
      end
      include Util::FingerprintHash::Immutable

      EMPTY = new(Util::EMPTY_ARY)

      private

      def node_subscript_token_child(value, token, *a, **kw)
        token = token.jsi_node_content if token.is_a?(Schema::SchemaAncestorNode)
        if value.respond_to?(:to_ary)
          if token.is_a?(String) && (token == '0' || token =~ POS_INT_RE)
            token = token.to_i
          elsif token == '-'
            # per rfc6901, - refers "to the (nonexistent) member after the last array element" and is
            # expected to raise an error condition.
            raise(ResolutionError, "Invalid resolution: #{token.inspect} refers to a nonexistent element in array #{value.inspect}")
          end
          size = (value.respond_to?(:size) ? value : value.to_ary).size
          unless token.is_a?(Integer) && token >= 0 && token < size
            raise(ResolutionError, "Invalid resolution: #{token.inspect} is not a valid array index of #{value.inspect}")
          end

          ary = (value.respond_to?(:[]) ? value : value.to_ary)
          if kw.empty?
            # TODO remove eventually (keyword argument compatibility)
            child = ary[token, *a]
          else
            child = ary[token, *a, **kw]
          end
        elsif value.respond_to?(:to_hash)
          unless (value.respond_to?(:key?) ? value : value.to_hash).key?(token)
            raise(ResolutionError, "Invalid resolution: #{token.inspect} is not a valid key of #{value.inspect}")
          end

          hsh = (value.respond_to?(:[]) ? value : value.to_hash)
          if kw.empty?
            # TODO remove eventually (keyword argument compatibility)
            child = hsh[token, *a]
          else
            child = hsh[token, *a, **kw]
          end
        else
          raise(ResolutionError, "Invalid resolution: #{token.inspect} cannot be resolved in #{value.inspect}")
        end
        [token, child]
      end
    end
end
