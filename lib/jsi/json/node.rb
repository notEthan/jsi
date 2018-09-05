module JSI
  module JSON
    # JSI::JSON::Node is an abstraction of a node within a JSON document.
    # it aims to act like the underlying data type of the node's content
    # (Hash or Array, generally) in most cases, defining methods of Hash
    # and Array which delegate to the content. However, destructive methods
    # are not defined, as modifying the content of a node would change it
    # for any other nodes in the document that contain or refer to it.
    #
    # methods that return a modified copy such as #merge are defined, and
    # return a copy of the document with the content of the node modified.
    # the original node's document and content are untouched.
    class Node
      # if the content of the document at the given path is a Hash, returns
      # a HashNode; if an Array, returns ArrayNode. otherwise returns a
      # regular Node, though, for the most part this will be called with Hash
      # or Array content.
      def self.new_by_type(document, path)
        node = Node.new(document, path)
        content = node.content
        if content.is_a?(Hash)
          HashNode.new(document, path)
        elsif content.is_a?(Array)
          ArrayNode.new(document, path)
        else
          node
        end
      end

      # a Node represents the content of a document at a given path.
      def initialize(document, path)
        raise(ArgumentError, "path must be an array. got: #{path.pretty_inspect.chomp} (#{path.class})") unless path.is_a?(Array)
        @document = document
        @path = path.dup.freeze
        @pointer = ::JSON::Schema::Pointer.new(:reference_tokens, path)
      end

      # the path of this Node within its document
      attr_reader :path
      # the document containing this Node at is path
      attr_reader :document
      # ::JSON::Schema::Pointer representing the path to this node within its document
      attr_reader :pointer

      # the raw content of this Node from the underlying document at this Node's path.
      def content
        pointer.evaluate(document)
      end

      def [](subscript)
        node = self
        content = node.content
        if content.is_a?(Hash) && !content.key?(subscript)
          node = node.deref
          content = node.content
        end
        begin
          subcontent = content[subscript]
        rescue TypeError => e
          raise(e.class, e.message + "\nsubscripting with #{subscript.pretty_inspect.chomp} (#{subscript.class}) from #{content.class.inspect}. self is: #{pretty_inspect.chomp}", e.backtrace)
        end
        if subcontent.respond_to?(:to_hash)
          HashNode.new(node.document, node.path + [subscript])
        elsif subcontent.respond_to?(:to_ary)
          ArrayNode.new(node.document, node.path + [subscript])
        else
          subcontent
        end
      end

      def []=(subscript, value)
        if value.is_a?(Node)
          content[subscript] = value.content
        else
          content[subscript] = value
        end
      end

      def deref
        content = self.content

        return self unless content.is_a?(Hash) && content['$ref'].is_a?(String)

        if content['$ref'][/\A#/]
          return self.class.new_by_type(document, ::JSON::Schema::Pointer.parse_fragment(content['$ref'])).deref
        end

        # HAX for how google does refs and ids
        if document_node['schemas'].respond_to?(:to_hash)
          if document_node['schemas'][content['$ref']]
            return document_node['schemas'][content['$ref']]
          end
          _, deref_by_id = document_node['schemas'].detect { |_k, schema| schema['id'] == content['$ref'] }
          if deref_by_id
            return deref_by_id
          end
        end

        #raise(NotImplementedError, "cannot dereference #{content['$ref']}") # TODO
        return self
      end

      # a Node at the root of the document
      def document_node
        Node.new_by_type(document, [])
      end

      # the parent of this node. if this node is the document root (its path is empty), raises
      # ::JSON::Schema::Pointer::ReferenceError.
      def parent_node
        if path.empty?
          raise(::JSON::Schema::Pointer::ReferenceError, "cannot access parent of root node: #{pretty_inspect.chomp}")
        else
          Node.new_by_type(document, path[0...-1])
        end
      end

      # the pointer path to this node within the document, per RFC 6901 https://tools.ietf.org/html/rfc6901
      def pointer_path
        pointer.pointer
      end
      # the pointer fragment to this node within the document, per RFC 6901 https://tools.ietf.org/html/rfc6901
      def fragment
        pointer.fragment
      end

      def as_json(*opt)
        Typelike.as_json(content, *opt)
      end

      # takes a block. the block is yielded the content of this node. the block MUST return a modified
      # copy of that content (and NOT modify the object it is given).
      def modified_copy
        # we need to preserve the rest of the document, but modify the content at our path.
        #
        # this is actually a bit tricky. we can't modify the original document, obviously.
        # we could do a deep copy, but that's expensive. instead, we make a copy of each array
        # or hash in the path above this node. this node's content is modified by the caller, and
        # that is recursively merged up to the document root. the recursion is done with a
        # y combinator, for no other reason than that was a fun way to implement it.
        modified_document = JSI.ycomb do |rec|
          proc do |subdocument, subpath|
            if subpath == []
              yield(subdocument)
            else
              car = subpath[0]
              cdr = subpath[1..-1]
              if subdocument.respond_to?(:to_hash)
                car_object = rec.call(subdocument[car], cdr)
                if car_object.object_id == subdocument[car].object_id
                  subdocument
                else
                  subdocument.merge({car => car_object})
                end
              elsif subdocument.respond_to?(:to_ary)
                if car.is_a?(String) && car =~ /\A\d+\z/
                  car = car.to_i
                end
                unless car.is_a?(Integer)
                  raise(TypeError, "bad subscript #{car.pretty_inspect.chomp} with remaining subpath: #{cdr.inspect} for array: #{subdocument.pretty_inspect.chomp}")
                end
                car_object = rec.call(subdocument[car], cdr)
                if car_object.object_id == subdocument[car].object_id
                  subdocument
                else
                  subdocument.dup.tap do |arr|
                    arr[car] = car_object
                  end
                end
              else
                raise(TypeError, "bad subscript: #{car.pretty_inspect.chomp} with remaining subpath: #{cdr.inspect} for content: #{subdocument.pretty_inspect.chomp}")
              end
            end
          end
        end.call(document, path)
        Node.new_by_type(modified_document, path)
      end

      def object_group_text
        "fragment=#{fragment.inspect}"
      end
      def inspect
        "\#<#{self.class.inspect} #{object_group_text} #{content.inspect}>"
      end
      def pretty_print(q)
        q.instance_exec(self) do |obj|
          text "\#<#{obj.class.inspect} #{obj.object_group_text}"
          group_sub {
            nest(2) {
              breakable ' '
              pp obj.content
            }
          }
          breakable ''
          text '>'
        end
      end

      def fingerprint
        {is_node: self.is_a?(JSI::JSON::Node), document: document, path: path}
      end
      include FingerprintHash
    end

    class ArrayNode < Node
      def each
        return to_enum(__method__) { content.size } unless block_given?
        content.each_index { |i| yield self[i] }
        self
      end

      def to_ary
        to_a
      end

      include Enumerable
      include Arraylike

      def as_json(*opt) # needs redefined after including Enumerable
        Typelike.as_json(content, *opt)
      end

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
      # we override these methods from Arraylike
      SAFE_INDEX_ONLY_METHODS.each do |method_name|
        define_method(method_name) { |*a, &b| content.public_send(method_name, *a, &b) }
      end
    end

    class HashNode < Node
      def each(&block)
        return to_enum(__method__) { content.size } unless block_given?
        if block.arity > 1
          content.each_key { |k| yield k, self[k] }
        else
          content.each_key { |k| yield [k, self[k]] }
        end
        self
      end

      def to_hash
        inject({}) { |h, (k, v)| h[k] = v; h }
      end

      include Enumerable
      include Hashlike

      def as_json(*opt) # needs redefined after including Enumerable
        Typelike.as_json(content, *opt)
      end

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
      SAFE_KEY_ONLY_METHODS.each do |method_name|
        define_method(method_name) { |*a, &b| content.public_send(method_name, *a, &b) }
      end
    end
  end
end
