require "json-schema"

# apply the changes from https://github.com/ruby-json-schema/json-schema/pull/382 

# json-schema/pointer.rb
require 'addressable/uri'

module JSON
  class Schema
    # a JSON Pointer, as described by RFC 6901 https://tools.ietf.org/html/rfc6901
    class Pointer
      class Error < JSON::Schema::SchemaError
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

      # initializes a JSON::Schema::Pointer from the given representation.
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
      def evaluate(document)
        reference_tokens.inject(document) do |value, token|
          if value.is_a?(Array)
            if token.is_a?(String) && token =~ /\A\d|[1-9]\d+\z/
              token = token.to_i
            end
            unless token.is_a?(Integer)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not an integer and cannot be resolved in array #{value.inspect}")
            end
            unless (0...value.size).include?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid index of #{value.inspect}")
            end
          elsif value.is_a?(Hash)
            unless value.key?(token)
              raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} is not a valid key of #{value.inspect}")
            end
          else
            raise(ReferenceError, "Invalid resolution for #{to_s}: #{token.inspect} cannot be resolved in #{value.inspect}")
          end
          value[token]
        end
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

# json-schema/validator.rb

module JSON
  class Validator
    def initialize(schema_data, data, opts={})
      @options = @@default_opts.clone.merge(opts)
      @errors = []

      validator = self.class.validator_for_name(@options[:version])
      @options[:version] = validator
      @options[:schema_reader] ||= self.class.schema_reader

      @validation_options = @options[:record_errors] ? {:record_errors => true} : {}
      @validation_options[:insert_defaults] = true if @options[:insert_defaults]
      @validation_options[:strict] = true if @options[:strict] == true
      @validation_options[:clear_cache] = true if !@@cache_schemas || @options[:clear_cache]

      @@mutex.synchronize { @base_schema = initialize_schema(schema_data) }
      @original_data = data
      @data = initialize_data(data)
      @@mutex.synchronize { build_schemas(@base_schema) }

      # If the :fragment option is set, try and validate against the fragment
      if opts[:fragment]
        @base_schema = schema_from_fragment(@base_schema, opts[:fragment])
      end

      # validate the schema, if requested
      if @options[:validate_schema]
        if @base_schema.schema["$schema"]
          base_validator = self.class.validator_for_name(@base_schema.schema["$schema"])
        end
        metaschema = base_validator ? base_validator.metaschema : validator.metaschema
        # Don't clear the cache during metaschema validation!
        self.class.validate!(metaschema, @base_schema.schema, {:clear_cache => false})
      end
    end

    def schema_from_fragment(base_schema, fragment)
      schema_uri = base_schema.uri

      pointer = JSON::Schema::Pointer.new(:fragment, fragment)

      base_schema = JSON::Schema.new(pointer.evaluate(base_schema.schema), schema_uri, @options[:version])

      if @options[:list]
        base_schema.to_array_schema
      elsif base_schema.is_a?(Hash)
        JSON::Schema.new(base_schema, schema_uri, @options[:version])
      else
        base_schema
      end
    end
  end
end
