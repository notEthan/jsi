require 'addressable/uri'

module JSI
  module JSON
    # a JSON Pointer, as described by RFC 6901 https://tools.ietf.org/html/rfc6901
    class Pointer
      class Error < StandardError
      end
      class PointerSyntaxError < Error
      end
      class ReferenceError < Error
      end

      # parse a URI-escaped fragment and instantiate as a JSI::JSON::Pointer
      #
      #     ptr = JSI::JSON::Pointer.from_fragment('#/foo/bar')
      #     => #<JSI::JSON::Pointer fragment: #/foo/bar>
      #     ptr.reference_tokens
      #     => ["foo", "bar"]
      #
      # with URI escaping:
      #
      #     ptr = JSI::JSON::Pointer.from_fragment('#/foo%20bar')
      #     => #<JSI::JSON::Pointer fragment: #/foo%20bar>
      #     ptr.reference_tokens
      #     => ["foo bar"]
      #
      # @param fragment [String] a fragment containing a pointer (starting with #)
      # @return [JSI::JSON::Pointer]
      def self.from_fragment(fragment)
        fragment = Addressable::URI.unescape(fragment)
        match = fragment.match(/\A#/)
        if match
          from_pointer(match.post_match, type: 'fragment')
        else
          raise(PointerSyntaxError, "Invalid fragment syntax in #{fragment.inspect}: fragment must begin with #")
        end
      end

      # parse a pointer string and instantiate as a JSI::JSON::Pointer
      #
      #     ptr1 = JSI::JSON::Pointer.from_pointer('/foo')
      #     => #<JSI::JSON::Pointer pointer: /foo>
      #     ptr1.reference_tokens
      #     => ["foo"]
      #
      #     ptr2 = JSI::JSON::Pointer.from_pointer('/foo~0bar/baz~1qux')
      #     => #<JSI::JSON::Pointer pointer: /foo~0bar/baz~1qux>
      #     ptr2.reference_tokens
      #     => ["foo~bar", "baz/qux"]
      #
      # @param pointer_string [String] a pointer string
      # @param type (for internal use) indicates the original representation of the pointer
      # @return [JSI::JSON::Pointer]
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
        '#' + Addressable::URI.escape(pointer)
      end

      # @return [Boolean] whether this pointer points to the root (has an empty array of reference_tokens)
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

      # appends the given token to this Pointer's reference tokens and returns the result
      #
      # @param token [Object]
      # @return [JSI::JSON::Pointer] pointer to a child node of this pointer with the given token
      def [](token)
        Pointer.new(reference_tokens + [token], type: @type)
      end

      # @return [String] string representation of this Pointer
      def inspect
        "#<#{self.class.inspect} #{representation_s}>"
      end

      # @return [String] string representation of this Pointer
      def to_s
        inspect
      end

      private

      # @return [String] a representation of this pointer based on @type
      def representation_s
        if @type == 'fragment'
          "fragment: #{fragment}"
        elsif @type == 'pointer'
          "pointer: #{pointer}"
        else
          "reference_tokens: #{reference_tokens.inspect}"
        end
      end
    end
  end
end
