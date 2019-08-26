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
      def self.new_doc(document)
        new_by_type(document, [])
      end

      # if the content of the document at the given path is Hash-like, returns
      # a HashNode; if Array-like, returns ArrayNode. otherwise returns a
      # regular Node, although Nodes are for the most part instantiated from
      # Hash or Array-like content.
      def self.new_by_type(document, path)
        node = Node.new(document, path)
        content = node.content
        if content.respond_to?(:to_hash)
          HashNode.new(document, path)
        elsif content.respond_to?(:to_ary)
          ArrayNode.new(document, path)
        else
          node
        end
      end

      # a Node represents the content of a document at a given path.
      def initialize(document, path)
        unless path.respond_to?(:to_ary)
          raise(ArgumentError, "path must be an array. got: #{path.pretty_inspect.chomp} (#{path.class})")
        end
        if document.is_a?(JSI::JSON::Node)
          raise(TypeError, "document of a Node should not be another JSI::JSON::Node: #{document.inspect}")
        end
        @document = document
        @path = path.to_ary.dup.freeze
        @pointer = JSI::JSON::Pointer.new(:reference_tokens, path)
      end

      # the path of this Node within its document
      attr_reader :path
      # the document containing this Node at is path
      attr_reader :document
      # JSI::JSON::Pointer representing the path to this node within its document
      attr_reader :pointer

      # the raw content of this Node from the underlying document at this Node's path.
      def content
        content = pointer.evaluate(document)
        content
      end

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
        node = self
        content = node.content
        if content.respond_to?(:to_hash) && !(content.respond_to?(:key?) ? content : content.to_hash).key?(subscript)
          node = node.deref
          content = node.content
        end
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
          HashNode.new(node.document, node.path + [subscript])
        elsif subcontent.respond_to?(:to_ary)
          ArrayNode.new(node.document, node.path + [subscript])
        else
          subcontent
        end
      end

      # assigns the given subscript of the content to the given value. the document is modified in place.
      def []=(subscript, value)
        if value.is_a?(Node)
          content[subscript] = value.content
        else
          content[subscript] = value
        end
      end

      # returns a Node, dereferencing a $ref attribute if possible. if this node is not hash-like,
      # does not have a $ref, or if what its $ref cannot be found, this node is returned.
      #
      # currently only $refs pointing within the same document are followed.
      def deref
        content = self.content

        if content.respond_to?(:to_hash)
          ref = (content.respond_to?(:[]) ? content : content.to_hash)['$ref']
        end
        return self unless ref.is_a?(String)

        if ref[/\A#/]
          return self.class.new_by_type(document, JSI::JSON::Pointer.parse_fragment(ref)).deref
        end

        # HAX for how google does refs and ids
        if document_node['schemas'].respond_to?(:to_hash)
          if document_node['schemas'][ref]
            return document_node['schemas'][ref]
          end
          _, deref_by_id = document_node['schemas'].detect { |_k, schema| schema['id'] == ref }
          if deref_by_id
            return deref_by_id
          end
        end

        #raise(NotImplementedError, "cannot dereference #{ref}") # TODO
        return self
      end

      # a Node at the root of the document
      def document_node
        Node.new_doc(document)
      end

      # the parent of this node. if this node is the document root (its path is empty), raises
      # JSI::JSON::Pointer::ReferenceError.
      def parent_node
        if path.empty?
          raise(JSI::JSON::Pointer::ReferenceError, "cannot access parent of root node: #{pretty_inspect.chomp}")
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

      # returns a jsonifiable representation of this node's content
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
        modified_document = JSI::Util.ycomb do |rec|
          proc do |subdocument, subpath|
            if subpath == []
              yield(subdocument)
            else
              car = subpath[0]
              cdr = subpath[1..-1]
              if subdocument.respond_to?(:to_hash)
                subdocument_car = (subdocument.respond_to?(:[]) ? subdocument : subdocument.to_hash)[car]
                car_object = rec.call(subdocument_car, cdr)
                if car_object.object_id == subdocument_car.object_id
                  subdocument
                else
                  (subdocument.respond_to?(:merge) ? subdocument : subdocument.to_hash).merge({car => car_object})
                end
              elsif subdocument.respond_to?(:to_ary)
                if car.is_a?(String) && car =~ /\A\d+\z/
                  car = car.to_i
                end
                unless car.is_a?(Integer)
                  raise(TypeError, "bad subscript #{car.pretty_inspect.chomp} with remaining subpath: #{cdr.inspect} for array: #{subdocument.pretty_inspect.chomp}")
                end
                subdocument_car = (subdocument.respond_to?(:[]) ? subdocument : subdocument.to_ary)[car]
                car_object = rec.call(subdocument_car, cdr)
                if car_object.object_id == subdocument_car.object_id
                  subdocument
                else
                  (subdocument.respond_to?(:[]=) ? subdocument : subdocument.to_ary).dup.tap do |arr|
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

      # meta-information about the object, outside the content. used by #inspect / #pretty_print
      def object_group_text
        "fragment=#{fragment.inspect}" + (content.respond_to?(:object_group_text) ? ' ' + content.object_group_text : '')
      end

      # a string representing this node
      def inspect
        "\#<#{self.class.inspect} #{object_group_text} #{content.inspect}>"
      end

      # pretty-prints a representation this node to the given printer
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

      # fingerprint for equality (see FingerprintHash). two nodes are equal if they are both nodes
      # (regardless of type, e.g. one may be a Node and the other may be a HashNode) within equal
      # documents at equal paths. note that this means two nodes with the same content may not be
      # considered equal.
      def fingerprint
        {class: JSI::JSON::Node, document: document, path: path}
      end
      include FingerprintHash
    end

    # a JSI::JSON::Node whose content is Array-like (responds to #to_ary)
    # and includes Array methods from Arraylike
    class ArrayNode < Node
      # iterates over each element in the same manner as Array#each
      def each
        return to_enum(__method__) { (content.respond_to?(:size) ? content : content.to_ary).size } unless block_given?
        (content.respond_to?(:each_index) ? content : content.to_ary).each_index { |i| yield self[i] }
        self
      end

      # the content of this ArrayNode, as an Array
      def to_ary
        to_a
      end

      include Enumerable
      include Arraylike

      # returns a jsonifiable representation of this node's content
      def as_json(*opt) # needs redefined after including Enumerable
        Typelike.as_json(content, *opt)
      end

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
      # we override these methods from Arraylike
      SAFE_INDEX_ONLY_METHODS.each do |method_name|
        define_method(method_name) { |*a, &b| (content.respond_to?(method_name) ? content : content.to_ary).public_send(method_name, *a, &b) }
      end
    end

    # a JSI::JSON::Node whose content is Hash-like (responds to #to_hash)
    # and includes Hash methods from Hashlike
    class HashNode < Node
      # iterates over each element in the same manner as Array#each
      def each(&block)
        return to_enum(__method__) { content.respond_to?(:size) ? content.size : content.to_ary.size } unless block_given?
        if block.arity > 1
          (content.respond_to?(:each_key) ? content : content.to_hash).each_key { |k| yield k, self[k] }
        else
          (content.respond_to?(:each_key) ? content : content.to_hash).each_key { |k| yield [k, self[k]] }
        end
        self
      end

      # the content of this HashNode, as a Hash
      def to_hash
        inject({}) { |h, (k, v)| h[k] = v; h }
      end

      include Enumerable
      include Hashlike

      # returns a jsonifiable representation of this node's content
      def as_json(*opt) # needs redefined after including Enumerable
        Typelike.as_json(content, *opt)
      end

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
      SAFE_KEY_ONLY_METHODS.each do |method_name|
        define_method(method_name) { |*a, &b| (content.respond_to?(method_name) ? content : content.to_hash).public_send(method_name, *a, &b) }
      end
    end
  end
end
