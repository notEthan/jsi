# frozen_string_literal: true

module JSI
  module Base::Enumerable
    include ::Enumerable

    # an Array containing each item in this JSI.
    #
    # @param kw keyword arguments are passed to {Base#[]} - see its keyword params
    # @return [Array]
    def to_a(**kw)
      # TODO remove eventually (keyword argument compatibility)
      # discard when all supported ruby versions Enumerable#to_a delegate keywords to #each (3.0.1 breaks; 2.7.x warns)
      # https://bugs.ruby-lang.org/issues/18289
      ary = []
      each(**kw) do |e|
        ary << e
      end
      ary.freeze
    end

    alias_method :entries, :to_a

    # a jsonifiable representation of the node content
    # @return [Object]
    def as_json(*opt)
      # include Enumerable (above) means, if ActiveSupport is loaded, its undesirable #as_json is included
      # https://github.com/rails/rails/blob/v7.0.0/activesupport/lib/active_support/core_ext/object/json.rb#L139-L143
      # although Base#as_json does clobber activesupport's, I want as_json defined correctly on the module too.
      Util.as_json(jsi_node_content, *opt)
    end
  end

  # module extending a {JSI::Base} object when its instance (its {Base#jsi_node_content})
  # is a Hash (or responds to `#to_hash`)
  module Base::HashNode
    include Base::Enumerable

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

    # (see Base#jsi_hash?)
    def jsi_hash?
      true
    end

    # (see Base#jsi_each_child_token)
    def jsi_each_child_token(&block)
      return to_enum(__method__) { jsi_node_content_hash_pubsend(:size) } unless block
      jsi_node_content_hash_pubsend(:each_key, &block)
      nil
    end

    # yields each hash key and value of this node.
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

    # a hash in which each key is a key of the instance hash and each value is the result of {Base#[]}
    # @param kw keyword arguments are passed to {Base#[]}
    # @return [Hash]
    def to_hash(**kw)
      hash = {}
      jsi_node_content_hash_pubsend(:each_key) { |k| hash[k] = self[k, **kw] }
      hash.freeze
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
    SAFE_KEY_ONLY_METHODS.each do |method_name|
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
    include Base::Enumerable

    # (see Base#jsi_array?)
    def jsi_array?
      true
    end

    # (see Base#jsi_each_child_token)
    def jsi_each_child_token(&block)
      return to_enum(__method__) { jsi_node_content_ary_pubsend(:size) } unless block
      jsi_node_content_ary_pubsend(:each_index, &block)
      nil
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
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
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
end
