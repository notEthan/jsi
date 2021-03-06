# frozen_string_literal: true

module JSI
  # including class MUST define
  # - #jsi_document [Object] returning the document
  # - #jsi_ptr [JSI::JSON::Pointer] returning a pointer for the node path in the document
  # - #jsi_root_node [JSI::PathedNode] returning a PathedNode pointing at the document root
  # - #jsi_parent_node [JSI::PathedNode] returning the parent node of this PathedNode
  #
  # given these, this module represents the node in the document at the path.
  #
  # the node content (#jsi_node_content) is the result of evaluating the node document at the path.
  module PathedNode
    # @return [Object] the content of this node
    def jsi_node_content
      content = jsi_ptr.evaluate(jsi_document)
      content
    end
  end

  # module extending a {JSI::PathedNode} object when its jsi_node_content is Hash-like (responds to #to_hash)
  module PathedHashNode
    # yields each hash key and value of this node.
    #
    # each yielded key is the same as a key of the node content hash,
    # and each yielded value is the result of self[key] (see #[]).
    #
    # returns an Enumerator if no block is given.
    #
    # @yield [Object, Object] each key and value of this hash node
    # @return [self, Enumerator] returns an Enumerator if invoked without a block; otherwise self
    def each(&block)
      return to_enum(__method__) { jsi_node_content_hash_pubsend(:size) } unless block
      if block.arity > 1
        jsi_node_content_hash_pubsend(:each_key) { |k| yield k, self[k] }
      else
        jsi_node_content_hash_pubsend(:each_key) { |k| yield [k, self[k]] }
      end
      self
    end

    # @return [Hash] a hash in which each key is a key of the jsi_node_content hash and
    #   each value is the result of self[key] (see #[]).
    def to_hash
      {}.tap { |h| jsi_node_content_hash_pubsend(:each_key) { |k| h[k] = self[k] } }
    end

    include Hashlike

    # @param method_name [String, Symbol]
    # @param a arguments and block are passed to the invocation of method_name
    # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_hash
    def jsi_node_content_hash_pubsend(method_name, *a, &b)
      if jsi_node_content.respond_to?(method_name)
        jsi_node_content.public_send(method_name, *a, &b)
      else
        jsi_node_content.to_hash.public_send(method_name, *a, &b)
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        jsi_node_content_hash_pubsend(method_name, *a, &b)
      end
    end
  end

  module PathedArrayNode
    # yields each array element of this node.
    #
    # each yielded element is the result of self[index] for each index of our array (see #[]).
    #
    # returns an Enumerator if no block is given.
    #
    # @yield [Object] each element of this array node
    # @return [self, Enumerator] returns an Enumerator if invoked without a block; otherwise self
    def each(&block)
      return to_enum(__method__) { jsi_node_content_ary_pubsend(:size) } unless block
      jsi_node_content_ary_pubsend(:each_index) { |i| yield(self[i]) }
      self
    end

    # @return [Array] an array, the same size as the jsi_node_content, in which the
    #   element at each index is the result of self[index] (see #[])
    def to_ary
      to_a
    end

    include Arraylike

    # @param method_name [String, Symbol]
    # @param a arguments and block are passed to the invocation of method_name
    # @return [Object] the result of calling method method_name on the jsi_node_content or its #to_ary
    def jsi_node_content_ary_pubsend(method_name, *a, &b)
      if jsi_node_content.respond_to?(method_name)
        jsi_node_content.public_send(method_name, *a, &b)
      else
        jsi_node_content.to_ary.public_send(method_name, *a, &b)
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        jsi_node_content_ary_pubsend(method_name, *a, &b)
      end
    end
  end
end
