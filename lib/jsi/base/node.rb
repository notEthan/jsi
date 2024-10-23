# frozen_string_literal: true

module JSI
  # module extending a {JSI::Base} object when its instance (its {Base#jsi_node_content})
  # is a Hash (or responds to `#to_hash`)
  module Base::HashNode
    # instantiates and yields each property name (hash key) as a JSI described by any `propertyNames` schemas.
    #
    # @yield [JSI::Base]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_propertyName
      return to_enum(__method__) { jsi_node_content_hash_pubsend(:size) } unless block_given?

      property_schemas = SchemaSet.build do |schemas|
        jsi_schemas.each do |s|
          if s.keyword?('propertyNames') && s['propertyNames'].is_a?(Schema)
            schemas << s['propertyNames']
          end
        end
      end
      jsi_node_content_hash_pubsend(:each_key) do |key|
        yield property_schemas.new_jsi(key)
      end

      nil
    end

    # See {Base#jsi_hash?}. Always true for HashNode.
    def jsi_hash?
      true
    end

    # Yields each key - see {Base#jsi_each_child_token}
    def jsi_each_child_token(&block)
      return to_enum(__method__) { jsi_node_content_hash_pubsend(:size) } unless block
      jsi_node_content_hash_pubsend(:each_key, &block)
      nil
    end

    # See {Base#jsi_child_token_present?}
    def jsi_child_token_present?(token)
      jsi_node_content_hash_pubsend(:key?, token)
    end

    # See {Base#jsi_node_content_child}
    def jsi_node_content_child(token)
      # I could check token_present? and return nil here (as ArrayNode does).
      # without that check, if the instance defines Hash#default or #default_proc, that result is returned.
      # the preferred mechanism for a JSI's default value should be its schema.
      # but there's no compelling reason not to support both, so I'll return what #[] returns.
      jsi_node_content_hash_pubsend(:[], token)
    end

    # See {Base#[]}
    def [](token, as_jsi: jsi_child_as_jsi_default, use_default: jsi_child_use_default_default)
      raise(BlockGivenError) if block_given?
      token = token.jsi_node_content if token.is_a?(Schema::SchemaAncestorNode)
      if jsi_node_content_hash_pubsend(:key?, token)
        jsi_child(token, as_jsi: as_jsi)
      else
        if use_default
          jsi_default_child(token, as_jsi: as_jsi)
        else
          nil
        end
      end
    end

    # yields each Hash key (JSON object property name) and value of this node.
    #
    # each yielded key is a key of the instance hash, and each yielded value is the result of {Base#[]}.
    #
    # @param kw keyword arguments are passed to {Base#[]}
    # @yield [Object, Object] each key and value of this hash node
    # @return [self, Enumerator] an Enumerator if invoked without a block; otherwise self
    def each(**kw, &block)
      return to_enum(__method__, **kw) { jsi_node_content_hash_pubsend(:size) } unless block
      if block.arity > 1
        jsi_node_content_hash_pubsend(:each_key) { |k| yield k, self[k, **kw] }
      else
        jsi_node_content_hash_pubsend(:each_key) { |k| yield [k, self[k, **kw]] }
      end
      self
    end

    # Yields each key (property name)
    # @param key_as_jsi [Boolean] Yield each key as a JSI instance, per {#jsi_each_propertyName}
    # @yield [String, Base]
    def each_key(key_as_jsi: false, &block)
      return to_enum(__method__, key_as_jsi: key_as_jsi) { size } unless block
      if key_as_jsi
        jsi_each_propertyName(&block)
      else
        jsi_node_content_hash_pubsend(:each_key, &block)
      end
      self
    end

    # a hash in which each key is a key of the instance hash and each value is the result of {Base#[]}
    # @param kw keyword arguments are passed to {Base#[]}
    # @return [Hash]
    def to_hash(**kw)
      hash = {}
      each_key { |k| hash[k] = self[k, **kw] }
      hash.freeze
    end

    # See {Base#as_json}
    def as_json(options = {})
      hash = {}
      each_key do |k|
        ks = k.is_a?(String) ? k :
          k.is_a?(Symbol) ? k.to_s :
          k.respond_to?(:to_str) && (kstr = k.to_str).is_a?(String) ? kstr :
          raise(TypeError, "JSON object (Hash) cannot be keyed with: #{k.pretty_inspect.chomp}")
        hash[ks] = jsi_child_node(k).as_json(**options)
      end
      hash
    end

    include Util::Hashlike

    if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
      # invokes the method with the given name on the jsi_node_content (if defined) or its #to_hash
      # @param method_name [String, Symbol]
      # @param a positional arguments are passed to the invocation of method_name
      # @param b block is passed to the invocation of method_name
      # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_hash
      def jsi_node_content_hash_pubsend(method_name, *a, &b)
        if jsi_node_content.respond_to?(method_name)
          jsi_node_content.public_send(method_name, *a, &b)
        else
          jsi_node_content.to_hash.public_send(method_name, *a, &b)
        end
      end
    else
      # invokes the method with the given name on the jsi_node_content (if defined) or its #to_hash
      # @param method_name [String, Symbol]
      # @param a positional arguments are passed to the invocation of method_name
      # @param kw keyword arguments are passed to the invocation of method_name
      # @param b block is passed to the invocation of method_name
      # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_hash
      def jsi_node_content_hash_pubsend(method_name, *a, **kw, &b)
        if jsi_node_content.respond_to?(method_name)
          jsi_node_content.public_send(method_name, *a, **kw, &b)
        else
          jsi_node_content.to_hash.public_send(method_name, *a, **kw, &b)
        end
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.reject { |m| instance_method(m).owner == self }.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) do |*a, &b|
          jsi_node_content_hash_pubsend(method_name, *a, &b)
        end
      else
        define_method(method_name) do |*a, **kw, &b|
          jsi_node_content_hash_pubsend(method_name, *a, **kw, &b)
        end
      end
    end
  end

  # module extending a {JSI::Base} object when its instance (its {Base#jsi_node_content})
  # is an Array (or responds to `#to_ary`)
  module Base::ArrayNode
    # See {Base#jsi_array?}. Always true for ArrayNode.
    def jsi_array?
      true
    end

    # Yields each index - see {Base#jsi_each_child_token}
    def jsi_each_child_token(&block)
      return to_enum(__method__) { jsi_node_content_ary_pubsend(:size) } unless block
      jsi_node_content_ary_pubsend(:each_index, &block)
      nil
    end

    # See {Base#jsi_child_token_present?}
    def jsi_child_token_present?(token)
      token.is_a?(Integer) && token >= 0 && token < jsi_node_content_ary_pubsend(:size)
    end

    # See {Base#jsi_node_content_child}
    def jsi_node_content_child(token)
      # we check token_present? here (unlike HashNode) because we do not want to pass
      # negative indices, Ranges, or non-Integers to Array#[]
      if jsi_child_token_present?(token)
        jsi_node_content_ary_pubsend(:[], token)
      else
        nil
      end
    end

    # See {Base#[]}
    def [](token, as_jsi: jsi_child_as_jsi_default, use_default: jsi_child_use_default_default)
      raise(BlockGivenError) if block_given?
      token = token.jsi_node_content if token.is_a?(Schema::SchemaAncestorNode)
      size = jsi_node_content_ary_pubsend(:size)
      if token.is_a?(Integer)
        if token < 0
          if token < -size
            nil
          else
            jsi_child(token + size, as_jsi: as_jsi)
          end
        else
          if token < size
            jsi_child(token, as_jsi: as_jsi)
          else
            if use_default
              jsi_default_child(token, as_jsi: as_jsi)
            else
              nil
            end
          end
        end
      elsif token.is_a?(Range)
        type_err = proc do
          raise(TypeError, [
            "given range does not contain Integers",
            "range: #{token.inspect}",
          ].join("\n"))
        end

        start_idx = token.begin
        if start_idx.is_a?(Integer)
          start_idx += size if start_idx < 0
          return Util::EMPTY_ARY if start_idx == size
          return nil if start_idx < 0 || start_idx > size
        elsif start_idx.nil?
          start_idx = 0
        else
          type_err.call
        end

        end_idx = token.end
        if end_idx.is_a?(Integer)
          end_idx += size if end_idx < 0
          end_idx += 1 unless token.exclude_end?
          end_idx = size if end_idx > size
          return Util::EMPTY_ARY if start_idx >= end_idx
        elsif end_idx.nil?
          end_idx = size
        else
          type_err.call
        end

        (start_idx...end_idx).map { |i| jsi_child(i, as_jsi: as_jsi) }.freeze
      else
        raise(TypeError, [
          "expected `token` param to be an Integer or Range",
          "token: #{token.inspect}",
        ].join("\n"))
      end
    end

    # yields each array element of this node.
    #
    # each yielded element is the result of {Base#[]} for each index of the instance array.
    #
    # @param kw keyword arguments are passed to {Base#[]}
    # @yield [Object] each element of this array node
    # @return [self, Enumerator] an Enumerator if invoked without a block; otherwise self
    def each(**kw, &block)
      return to_enum(__method__, **kw) { jsi_node_content_ary_pubsend(:size) } unless block
      jsi_node_content_ary_pubsend(:each_index) { |i| yield(self[i, **kw]) }
      self
    end

    # an array, the same size as the instance array, in which the element at each index is the
    # result of {Base#[]}.
    # @param kw keyword arguments are passed to {Base#[]}
    # @return [Array]
    def to_ary(**kw)
      to_a(**kw)
    end

    # See {Base#as_json}
    def as_json(options = {})
      each_index.map { |i| jsi_child_node(i).as_json(**options) }
    end

    include Util::Arraylike

    if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
      # invokes the method with the given name on the jsi_node_content (if defined) or its #to_ary
      # @param method_name [String, Symbol]
      # @param a positional arguments are passed to the invocation of method_name
      # @param b block is passed to the invocation of method_name
      # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_ary
      def jsi_node_content_ary_pubsend(method_name, *a, &b)
        if jsi_node_content.respond_to?(method_name)
          jsi_node_content.public_send(method_name, *a, &b)
        else
          jsi_node_content.to_ary.public_send(method_name, *a, &b)
        end
      end
    else
      # invokes the method with the given name on the jsi_node_content (if defined) or its #to_ary
      # @param method_name [String, Symbol]
      # @param a positional arguments are passed to the invocation of method_name
      # @param kw keyword arguments are passed to the invocation of method_name
      # @param b block is passed to the invocation of method_name
      # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_ary
      def jsi_node_content_ary_pubsend(method_name, *a, **kw, &b)
        if jsi_node_content.respond_to?(method_name)
          jsi_node_content.public_send(method_name, *a, **kw, &b)
        else
          jsi_node_content.to_ary.public_send(method_name, *a, **kw, &b)
        end
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.reject { |m| instance_method(m).owner == self }.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) do |*a, &b|
          jsi_node_content_ary_pubsend(method_name, *a, &b)
        end
      else
        define_method(method_name) do |*a, **kw, &b|
          jsi_node_content_ary_pubsend(method_name, *a, **kw, &b)
        end
      end
    end
  end

  module Base::StringNode
    delegate_methods = %w(% * + << =~ [] []=
      ascii_only? b byteindex byterindex bytes bytesize byteslice bytesplice capitalize capitalize!
      casecmp casecmp? center chars chomp chomp! chop chop! chr clear codepoints concat count delete delete!
      delete_prefix delete_prefix! delete_suffix delete_suffix! downcase downcase!
      each_byte each_char each_codepoint each_grapheme_cluster each_line
      empty? encode encode! encoding end_with? force_encoding getbyte grapheme_clusters gsub gsub! hex
      include? index insert intern length lines ljust lstrip lstrip! match match? next next! oct ord
      partition prepend replace reverse reverse! rindex rjust rpartition rstrip rstrip! scan scrub scrub!
      setbyte size slice slice! split squeeze squeeze! start_with? strip strip! sub sub! succ succ! sum
      swapcase swapcase! to_c to_f to_i to_r to_s to_str to_sym tr tr! tr_s tr_s!
      unicode_normalize unicode_normalize! unicode_normalized? unpack unpack1 upcase upcase! upto valid_encoding?
    )
    delegate_methods.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) do |*a, &b|
          if jsi_node_content.respond_to?(method_name)
            jsi_node_content.public_send(method_name, *a, &b)
          else
            jsi_node_content.to_str.public_send(method_name, *a, &b)
          end
        end
      else
        define_method(method_name) do |*a, **kw, &b|
          if jsi_node_content.respond_to?(method_name)
            jsi_node_content.public_send(method_name, *a, **kw, &b)
          else
            jsi_node_content.to_str.public_send(method_name, *a, **kw, &b)
          end
        end
      end
    end
  end
end
