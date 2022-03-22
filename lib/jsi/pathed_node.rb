# frozen_string_literal: true

module JSI
  # module extending a {JSI::Base} object when its instance (its {Base#jsi_node_content})
  # is a Hash (or responds to `#to_hash`)
  module PathedHashNode
    # yields each hash key and value of this node.
    #
    # each yielded key is a key of the instance hash, and each yielded value is the result of {Base#[]}.
    #
    # returns an Enumerator if no block is given.
    #
    # @param kw keyword arguments are passed to {Base#[]}
    # @yield [Object, Object] each key and value of this hash node
    # @return [self, Enumerator] an Enumerator if invoked without a block; otherwise self
    def each(**kw, &block)
      return to_enum(__method__) { jsi_node_content_hash_pubsend(:size) } unless block
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
      {}.tap { |h| jsi_node_content_hash_pubsend(:each_key) { |k| h[k] = self[k, **kw] } }
    end

    include Hashlike

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
  module PathedArrayNode
    # yields each array element of this node.
    #
    # each yielded element is the result of {Base#[]} for each index of the instance array.
    #
    # returns an Enumerator if no block is given.
    #
    # @param kw keyword arguments are passed to {Base#[]}
    # @yield [Object] each element of this array node
    # @return [self, Enumerator] an Enumerator if invoked without a block; otherwise self
    def each(**kw, &block)
      return to_enum(__method__) { jsi_node_content_ary_pubsend(:size) } unless block
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

    include Arraylike

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
