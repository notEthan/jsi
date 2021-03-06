# frozen_string_literal: true

module JSI
  module Util
    # like a Struct, but stores all the attributes in one @attributes Hash, instead of individual instance
    # variables for each attribute.
    # this tends to be easier to work with and more flexible. keys which are symbols are converted to strings.
    class AttrStruct
      class AttrStructError < StandardError
      end

      class UndefinedAttributeKey < AttrStructError
      end

      class << self
        # creates a AttrStruct subclass with the given attribute keys.
        # @param attribute_keys [Enumerable<String, Symbol>]
        def [](*attribute_keys)
          unless self == AttrStruct
            # :nocov:
            raise(NotImplementedError, "AttrStruct multiple inheritance not supported")
            # :nocov:
          end

          bad = attribute_keys.reject { |key| key.respond_to?(:to_str) || key.is_a?(Symbol) }
          unless bad.empty?
            raise ArgumentError, "attribute keys must be String or Symbol; got keys: #{bad.map(&:inspect).join(', ')}"
          end
          attribute_keys = attribute_keys.map { |key| key.is_a?(Symbol) ? key.to_s : key }

          Class.new(AttrStruct).tap do |klass|
            klass.define_singleton_method(:attribute_keys) { attribute_keys }
            klass.send(:define_method, :attribute_keys) { attribute_keys }
            attribute_keys.each do |attribute_key|
              # reader
              klass.send(:define_method, attribute_key) do
                @attributes[attribute_key]
              end

              # writer
              klass.send(:define_method, "#{attribute_key}=") do |value|
                @attributes[attribute_key] = value
              end
            end
          end
        end
      end

      def initialize(attributes = {})
        unless attributes.respond_to?(:to_hash)
          raise(TypeError, "expected attributes to be a Hash; got: #{attributes.inspect}")
        end
        attributes = attributes.map { |k, v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
        bad = attributes.keys.reject { |k| self.attribute_keys.include?(k) }
        unless bad.empty?
          raise UndefinedAttributeKey, "undefined attribute keys: #{bad.map(&:inspect).join(', ')}"
        end
        @attributes = attributes
      end

      def [](key)
        key = key.to_s if key.is_a?(Symbol)
        @attributes[key]
      end

      def []=(key, value)
        key = key.to_s if key.is_a?(Symbol)
        unless self.attribute_keys.include?(key)
          raise UndefinedAttributeKey, "undefined attribute key: #{key.inspect}"
        end
        @attributes[key] = value
      end

      # @return [String]
      def inspect
        "\#<#{self.class.name}#{@attributes.empty? ? '' : ' '}#{@attributes.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')}>"
      end

      # pretty-prints a representation of self to the given printer
      # @return [void]
      def pretty_print(q)
        q.text '#<'
        q.text self.class.name
        q.group_sub {
          q.nest(2) {
            q.breakable(@attributes.empty? ? '' : ' ')
            q.seplist(@attributes, nil, :each_pair) { |k, v|
              q.group {
                q.text k
                q.text ': '
                q.pp v
              }
            }
          }
        }
        q.breakable ''
        q.text '>'
      end

      include FingerprintHash
      def jsi_fingerprint
        {class: self.class, attributes: @attributes}
      end
    end
  end
end
