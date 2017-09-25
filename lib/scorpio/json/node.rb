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
        raise(ArgumentError, "path must be an array. got: #{path.inspect} (#{path.class})") unless path.is_a?(Array)
        @document = document
        @path = path.dup.freeze
      end

      attr_reader :path
      attr_reader :document

      def content
        path.inject(document) do |element, part|
          if element.is_a?(Array)
            if part.is_a?(String) && part =~ /\A\d+\z/
              part = part.to_i
            end
            unless part.is_a?(Integer)
              raise
            end
          end
          raise("subscripting #{part} from element #{element.inspect}") unless element.is_a?(Array) || element.is_a?(Hash)
          element[part]
        end
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
          raise(e.class, e.message + "\nsubscripting from #{content.inspect} (#{content.class}): #{k.inspect} (#{k.class})", e.backtrace)
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

        match = content['$ref'].match(/\A#/)
        if match
          return self.class.new_by_type(document, Hana::Pointer.parse(match.post_match)).deref
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

      ESC = {'^' => '^^', '~' => '~0', '/' => '~1'} # '/' => '^/' ?
      def pointer_path
        path.map { |part| "/" + part.to_s.gsub(/[\^~\/]/) { |m| ESC[m] } }.join('')
      end
      def fragment
        "#" + pointer_path
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

      # hash methods - define only those which do not modify the hash.

      # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
      key_methods = %w(each_key empty? include? has_key? key key? keys length member? size)
      key_methods.each do |method_name|
        define_method(method_name) { |*a, &b| content.public_send(method_name, *a, &b) }
      end

      # methods which use key and value
      hash_methods = %w(any? compact dig each_pair each_value fetch fetch_values has_value? invert merge rassoc reject select to_h transform_values value? values values_at)
      hash_methods.each do |method_name|
        define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
      end
    end
  end
end
