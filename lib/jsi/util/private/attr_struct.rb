# frozen_string_literal: true

module JSI
  module Util::Private
    # like a Struct, but stores all the attributes in one @attributes Hash, instead of individual instance
    # variables for each attribute.
    # this tends to be easier to work with and more flexible. keys which are symbols are converted to strings.
    class AttrStruct
      class AttrStructError < StandardError
      end

      class UndefinedAttributeKey < AttrStructError
      end

      include(Util::Pretty)

      class << self
        # creates a AttrStruct subclass with the given attribute keys.
        # @param attribute_keys [Enumerable<String, Symbol>]
        def subclass(*attribute_keys)
          bad_type = attribute_keys.reject { |key| key.respond_to?(:to_str) || key.is_a?(Symbol) }
          unless bad_type.empty?
            raise(ArgumentError, "attribute keys must be String or Symbol; got keys: #{bad_type.map(&:inspect).join(', ')}")
          end

          attribute_keys = attribute_keys.map { |key| convert_key(key) }

          bad_name = attribute_keys.reject { |key| Util::Private.ok_ruby_method_name?(key) }
          unless bad_name.empty?
            raise(ArgumentError, "attribute keys must be valid ruby method names; got keys: #{bad_name.map(&:inspect).join(', ')}")
          end

          all_attribute_keys = (self.attribute_keys + attribute_keys).freeze

          Class.new(self) do
            define_singleton_method(:attribute_keys) { all_attribute_keys }

            attribute_keys.each do |attribute_key|
              # reader
              define_method(attribute_key) do
                @attributes[attribute_key]
              end

              # writer
              define_method("#{attribute_key}=") do |value|
                @attributes[attribute_key] = value
              end
            end
          end
        end

        alias_method :[], :subclass

        # the attribute keys defined for this class
        # @return [Set<String>]
        def attribute_keys
          # empty for AttrStruct itself; redefined on each subclass
          Util::Private::EMPTY_SET
        end

        # returns a frozen string, given a string or symbol.
        # returns anything else as-is for the caller to handle.
        # @api private
        def convert_key(key)
          # TODO use Symbol#name when available on supported rubies
          key.is_a?(Symbol) ? key.to_s.freeze : key.frozen? ? key : key.is_a?(String) ? key.dup.freeze : key
        end
      end

      def initialize(attributes = {})
        unless attributes.respond_to?(:to_hash)
          raise(TypeError, "expected attributes to be a Hash; got: #{attributes.inspect}")
        end
        @attributes = {}
        attributes.to_hash.each do |k, v|
          @attributes[self.class.convert_key(k)] = v
        end
        bad = @attributes.each_key.reject { |k| class_attribute_keys.include?(k) }
        unless bad.empty?
          raise(UndefinedAttributeKey, "undefined attribute keys for #{self.class}: #{bad.map(&:inspect).join(', ')}")
        end
      end

      def [](key)
        @attributes[key.is_a?(Symbol) ? key.to_s : key]
      end

      def []=(key, value)
        key = self.class.convert_key(key)
        unless class_attribute_keys.include?(key)
          raise UndefinedAttributeKey, "undefined attribute key: #{key.inspect}"
        end
        @attributes[key] = value
      end

      # pretty-prints a representation of self to the given printer
      # @return [void]
      def pretty_print(q)
        jsi_pp_object_group(q, empty: @attributes.empty?) do
            q.seplist(@attributes) { |k, v|
                q.text k
                q.text ': '
                q.pp v
            }
        end
      end

      # (see AttrStruct.attribute_keys)
      def class_attribute_keys
        self.class.attribute_keys
      end

      # @return [Hash]
      def to_h
        @attributes.frozen? ? @attributes : @attributes.dup.freeze
      end

      def freeze
        @attributes.freeze
        super
      end

      include FingerprintHash

      # see {Util::Private::FingerprintHash}
      # @api private
      def jsi_fingerprint
        {class: self.class, attributes: @attributes}.freeze
      end
    end
  end
end
