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

      # parse a fragment to an array of reference tokens
      #
      # #/foo/bar
      #
      # => ['foo', 'bar']
      #
      # #/foo%20bar
      #
      # => ['foo bar']
      def self.parse_fragment(fragment)
        fragment = Addressable::URI.unescape(fragment)
        match = fragment.match(/\A#/)
        if match
          parse_pointer(match.post_match)
        else
          raise(PointerSyntaxError, "Invalid fragment syntax in #{fragment.inspect}: fragment must begin with #")
        end
      end

      # parse a pointer to an array of reference tokens
      #
      # /foo
      #
      # => ['foo']
      #
      # /foo~0bar/baz~1qux
      #
      # => ['foo~bar', 'baz/qux']
      def self.parse_pointer(pointer_string)
        tokens = pointer_string.split('/', -1).map! do |piece|
          piece.gsub('~1', '/').gsub('~0', '~')
        end
        if tokens[0] == ''
          tokens[1..-1]
        elsif tokens.empty?
          tokens
        else
          raise(PointerSyntaxError, "Invalid pointer syntax in #{pointer_string.inspect}: pointer must begin with /")
        end
      end

      # initializes a JSI::JSON::Pointer from the given representation.
      #
      # type may be one of:
      #
      # - :fragment - the representation is a fragment containing a pointer (starting with #)
      # - :pointer - the representation is a pointer (starting with /)
      # - :reference_tokens - the representation is an array of tokens referencing a path in a document
      def initialize(type, representation)
        @type = type
        if type == :reference_tokens
          reference_tokens = representation
        elsif type == :fragment
          reference_tokens = self.class.parse_fragment(representation)
        elsif type == :pointer
          reference_tokens = self.class.parse_pointer(representation)
        else
          raise ArgumentError, "invalid initialization type: #{type.inspect} with representation #{representation.inspect}"
        end
        @reference_tokens = reference_tokens.map(&:freeze).freeze
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

      # the pointer string representation of this Pointer
      def pointer
        reference_tokens.map { |t| '/' + t.to_s.gsub('~', '~0').gsub('/', '~1') }.join('')
      end

      # the fragment string representation of this Pointer
      def fragment
        '#' + Addressable::URI.escape(pointer)
      end

      def to_s
        "#<#{self.class.inspect} #{@type} = #{representation_s}>"
      end

      private

      def representation_s
        if @type == :fragment
          fragment
        elsif @type == :pointer
          pointer
        else
          reference_tokens.inspect
        end
      end
    end
  end
end
