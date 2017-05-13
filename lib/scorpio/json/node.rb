module Scorpio
  module JSON
    class Node
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

      def each
        if content.is_a?(Hash)
          content.each_key { |k| yield k, self[k] }
        elsif content.is_a?(Array)
          content.each_index { |i| yield self[i] }
        else
          raise(ArgumentError, "#each not implemented for #{content.class}: #{content.inspect}")
        end
        self
      end
      include Enumerable

      def [](k)
        begin
          el = content[k]
        rescue TypeError => e
          raise(e.class, e.message + "\nsubscripting from #{content.inspect} (#{content.class}): #{k.inspect} (#{k.class})", e.backtrace)
        end
        if el.is_a?(Hash) || el.is_a?(Array)
          self.class.new(document, path + [k]).deref
        else
          el
        end
      end

      def deref
        content = self.content

        return self unless content.is_a?(Hash) && content['$ref'].is_a?(String)

        match = content['$ref'].match(/\A#/)
        if match
          return self.class.new(document, Hana::Pointer.parse(match.post_match))
        end

        #raise(NotImplementedError, "cannot dereference #{content['$ref']}") # TODO
        return self
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
  end
end
