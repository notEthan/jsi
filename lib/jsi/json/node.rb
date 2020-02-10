# frozen_string_literal: true

module JSI
  module JSON
    # JSI::JSON::Node is an abstraction of a node within a JSON document.
    # it aims to act like the underlying data type of the node's content
    # (generally Hash or Array-like) in most cases.
    #
    # the main advantage offered by using a Node over the underlying data
    # is in dereferencing. if a Node consists of a hash with a $ref property
    # pointing within the same document, then the Node will transparently
    # follow the ref and return the referenced data.
    #
    # in most other respects, a Node aims to act like a Hash when the content
    # is Hash-like, an Array when the content is Array-like. methods of Hash
    # and Array are defined and delegated to the node's content.
    #
    # however, destructive methods are for the most part not implemented.
    # at the moment only #[]= is implemented. since Node thinly wraps the
    # underlying data, you can change the data and it will be reflected in
    # the node. implementations of destructive methods are planned.
    #
    # methods that return a modified copy such as #merge are defined, and
    # return a copy of the document with the content of the node modified.
    # the original node's document and content are untouched.
    class Node
      include Enumerable
      include PathedNode

      def self.new_doc(node_document)
        new_by_type(node_document, JSI::JSON::Pointer.new([]))
      end

      # if the content of the document at the given pointer is Hash-like, returns
      # a HashNode; if Array-like, returns ArrayNode. otherwise returns a
      # regular Node, although Nodes are for the most part instantiated from
      # Hash or Array-like content.
      def self.new_by_type(node_document, node_ptr)
        content = node_ptr.evaluate(node_document)
        if content.respond_to?(:to_hash)
          HashNode.new(node_document, node_ptr)
        elsif content.respond_to?(:to_ary)
          ArrayNode.new(node_document, node_ptr)
        else
          Node.new(node_document, node_ptr)
        end
      end

      # a Node represents the content of a document at a given pointer.
      def initialize(node_document, node_ptr)
        unless node_ptr.is_a?(JSI::JSON::Pointer)
          raise(TypeError, "node_ptr must be a JSI::JSON::Pointer. got: #{node_ptr.pretty_inspect.chomp} (#{node_ptr.class})")
        end
        if node_document.is_a?(JSI::JSON::Node)
          raise(TypeError, "node_document of a Node should not be another JSI::JSON::Node: #{node_document.inspect}")
        end
        @node_document = node_document
        @node_ptr = node_ptr
      end

      # the document containing this Node at our pointer
      attr_reader :node_document

      # JSI::JSON::Pointer pointing to this node within its document
      attr_reader :node_ptr

      # returns content at the given subscript - call this the subcontent.
      #
      # if the content cannot be subscripted, raises TypeError.
      #
      # if the subcontent is Hash-like, it is wrapped as a JSI::JSON::HashNode before being returned.
      # if the subcontent is Array-like, it is wrapped as a JSI::JSON::ArrayNode before being returned.
      #
      # if this node's content is a $ref - that is, a hash with a $ref attribute - and the subscript is
      # not a key of the hash, then the $ref is followed before returning the subcontent.
      def [](subscript)
        ptr = self.node_ptr
        content = self.node_content
        unless content.respond_to?(:[])
          if content.respond_to?(:to_hash)
            content = content.to_hash
          elsif content.respond_to?(:to_ary)
            content = content.to_ary
          else
            raise(NoMethodError, "undefined method `[]`\nsubscripting with #{subscript.pretty_inspect.chomp} (#{subscript.class}) from #{content.class.inspect}. content is: #{content.pretty_inspect.chomp}")
          end
        end
        begin
          subcontent = content[subscript]
        rescue TypeError => e
          raise(e.class, e.message + "\nsubscripting with #{subscript.pretty_inspect.chomp} (#{subscript.class}) from #{content.class.inspect}. content is: #{content.pretty_inspect.chomp}", e.backtrace)
        end
        if subcontent.respond_to?(:to_hash)
          HashNode.new(node_document, ptr[subscript])
        elsif subcontent.respond_to?(:to_ary)
          ArrayNode.new(node_document, ptr[subscript])
        else
          subcontent
        end
      end

      # assigns the given subscript of the content to the given value. the document is modified in place.
      def []=(subscript, value)
        if value.is_a?(Node)
          node_content[subscript] = value.node_content
        else
          node_content[subscript] = value
        end
      end

      # returns a Node, dereferencing a $ref attribute if possible. if this node is not hash-like,
      # does not have a $ref, or if what its $ref cannot be found, this node is returned.
      #
      # currently only $refs pointing within the same document are followed.
      #
      # @yield [Node] if a block is given (optional), this will yield a deref'd node. if this
      #   node is not a $ref object, the block is not called. if we are a $ref which cannot be followed
      #   (e.g. a $ref to an external document, which is not yet supported), the block is not called.
      # @return [JSI::JSON::Node] dereferenced node, or this node
      def deref(&block)
        node_ptr_deref do |deref_ptr|
          return Node.new_by_type(node_document, deref_ptr).tap(&(block || Util::NOOP))
        end
        return self
      end

      # a Node at the root of the document
      def document_root_node
        Node.new_doc(node_document)
      end

      # the parent of this node. if this node is the document root, raises
      # JSI::JSON::Pointer::ReferenceError.
      def parent_node
        Node.new_by_type(node_document, node_ptr.parent)
      end

      # returns a jsonifiable representation of this node's content
      def as_json(*opt)
        Typelike.as_json(node_content, *opt)
      end

      # takes a block. the block is yielded the content of this node. the block MUST return a modified
      # copy of that content (and NOT modify the object it is given).
      def modified_copy(&block)
        Node.new_by_type(node_ptr.modified_document_copy(node_document, &block), node_ptr)
      end

      def dup
        modified_copy(&:dup)
      end

      # meta-information about the object, outside the content. used by #inspect / #pretty_print
      # @return [Array<String>]
      def object_group_text
        [
          self.class.inspect,
          "fragment=#{node_ptr.fragment.inspect}",
        ] + (node_content.respond_to?(:object_group_text) ? node_content.object_group_text : [])
      end

      # a string representing this node
      def inspect
        "\#<#{object_group_text.join(' ')} #{node_content.inspect}>"
      end

      # pretty-prints a representation this node to the given printer
      def pretty_print(q)
        q.text '#<'
        q.text object_group_text.join(' ')
        q.group_sub {
          q.nest(2) {
            q.breakable ' '
            q.pp node_content
          }
        }
        q.breakable ''
        q.text '>'
      end

      # fingerprint for equality (see FingerprintHash). two nodes are equal if they are both nodes
      # (regardless of type, e.g. one may be a Node and the other may be a HashNode) within equal
      # documents at equal pointers. note that this means two nodes with the same content may not be
      # considered equal.
      def fingerprint
        {class: JSI::JSON::Node, node_document: node_document, node_ptr: node_ptr}
      end
      include FingerprintHash
    end

    # a JSI::JSON::Node whose content is Array-like (responds to #to_ary)
    # and includes Array methods from Arraylike
    class ArrayNode < Node
      include PathedArrayNode
    end

    # a JSI::JSON::Node whose content is Hash-like (responds to #to_hash)
    # and includes Hash methods from Hashlike
    class HashNode < Node
      include PathedHashNode
    end
  end
end
