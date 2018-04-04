require 'scorpio/typelike_modules'

module Scorpio
  module JSON
    class Node
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

      def initialize(document, path)
        raise(ArgumentError, "path must be an array. got: #{path.pretty_inspect} (#{path.class})") unless path.is_a?(Array)
        define_singleton_method(:document) { document }
        @path = path.dup.freeze
        @pointer = ::JSON::Schema::Pointer.new(:reference_tokens, path)
      end

      attr_reader :path
      attr_reader :document
      attr_reader :pointer

      def content
        pointer.evaluate(document)
      end

      def [](k)
        node = self
        content = node.content
        if content.is_a?(Hash) && !content.key?(k)
          node = node.deref
          content = node.content
        end
        begin
          el = content[k]
        rescue TypeError => e
          raise(e.class, e.message + "\nsubscripting from #{content.pretty_inspect} (#{content.class}): #{k.pretty_inspect} (#{k.class})", e.backtrace)
        end
        if el.is_a?(Hash) || el.is_a?(Array)
          self.class.new_by_type(node.document, node.path + [k])
        else
          el
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

      def document_node
        Node.new_by_type(document, [])
      end

      def pointer_path
        pointer.pointer
      end
      def fragment
        pointer.fragment
      end

      def object_group_text
        "fragment=#{fragment.inspect}"
      end
      def inspect
        "\#<#{self.class.name} #{object_group_text} #{content.inspect}>"
      end
      def pretty_print(q)
        q.instance_exec(self) do |obj|
          text "\#<#{obj.class.name} #{object_group_text}"
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
        {class: self.class, document: document, path: path}
      end

      def ==(other)
        other.fingerprint == self.fingerprint
      end

      alias eql? ==

      def hash
        fingerprint.hash
      end
    end

    class ArrayNode < Node
      def each
        return to_enum(__method__) { content.size } unless block_given?
        content.each_index { |i| yield self[i] }
        self
      end
      include Enumerable

      def to_ary
        to_a
      end

      include Arraylike

      # array methods - define only those which do not modify the array.

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a)
      index_methods = %w(each_index empty? length size)
      index_methods.each do |method_name|
        define_method(method_name) { |*a, &b| content.public_send(method_name, *a, &b) }
      end

      # methods which use index and value.
      # flatten is omitted. flatten should not exist.
      array_methods = %w(& | * + - <=> abbrev assoc at bsearch bsearch_index combination compact count cycle dig fetch index first include? join last pack permutation rassoc repeated_combination reject reverse reverse_each rindex rotate sample select shelljoin shuffle slice sort take take_while transpose uniq values_at zip)
      array_methods.each do |method_name|
        define_method(method_name) { |*a, &b| to_a.public_send(method_name, *a, &b) }
      end
    end

    class HashNode < Node
      def each
        return to_enum(__method__) { content.size } unless block_given?
        content.each_key { |k| yield k, self[k] }
        self
      end
      include Enumerable

      def to_hash
        inject({}) { |h, (k, v)| h[k] = v; h }
      end

      include Hashlike

      # hash methods - define only those which do not modify the hash.

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
      key_methods = %w(each_key empty? include? has_key? key key? keys length member? size)
      key_methods.each do |method_name|
        define_method(method_name) { |*a, &b| content.public_send(method_name, *a, &b) }
      end

      # methods which use key and value
      hash_methods = %w(any? compact dig each_pair each_value fetch fetch_values has_value? invert rassoc reject select to_h transform_values value? values values_at)
      hash_methods.each do |method_name|
        define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
      end

      # methods that return a modified copy
      def merge(other)
        # we need to preserve the rest of the document, but modify the content at our path.
        #
        # this is actually a bit tricky. we can't modify the original document, obviously.
        # we could do a deep copy, but that's expensive. instead, we make a copy of each array
        # or hash in the path above this node. this node's content is merged with `other`, and
        # that is recursively merged up to the document root. the recursion is done with a
        # y combinator, for no other reason than that was a fun way to implement it.
        merged_document = ycomb do |rec|
          proc do |subdocument, subpath|
            if subpath == []
              subdocument.merge(other.is_a?(JSON::Node) ? other.content : other)
            else
              car = subpath[0]
              cdr = subpath[1..-1]
              if subdocument.is_a?(Array)
                if car.is_a?(String) && car =~ /\A\d+\z/
                  car = car.to_i
                end
                unless car.is_a?(Integer)
                  raise(TypeError, "bad subscript #{car.pretty_inspect} with remaining subpath: #{cdr.inspect} for array: #{subdocument.pretty_inspect}")
                end
              end
              car_object = rec.call(subdocument[car], cdr)
              if car_object == subdocument[car]
                subdocument
              elsif subdocument.is_a?(Hash)
                subdocument.merge({car => car_object})
              elsif subdocument.is_a?(Array)
                subdocument.dup.tap do |arr|
                  arr[car] = car_object
                end
              else
                raise(TypeError, "bad subscript: #{car.pretty_inspect} with remaining subpath: #{cdr.inspect} for content: #{subdocument.pretty_inspect}")
              end
            end
          end
        end.call(document, path)
        self.class.new(merged_document, path)
      end
    end
  end
end
