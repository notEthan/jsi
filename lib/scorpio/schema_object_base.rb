require 'hana'
require 'json'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
  end

  CLASS_FOR_SCHEMA = Hash.new do |h, schema_node_|
    h[schema_node_] = Class.new(SchemaObjectBase).instance_exec(schema_node_) do |schema_node|
      define_singleton_method(:schema_node) { schema_node }
      define_singleton_method(:class_schema) { schema_node.content }
      define_singleton_method(:schema_document) { schema_node.document }
      define_singleton_method(:schema_path) { schema_node.path }
      define_method(:schema_node) { schema_node }
      define_method(:class_schema) { schema_node.content }
      define_method(:schema_document) { schema_node.document }
      define_method(:schema_path) { schema_node.path }

      define_method(:initialize) do |object|
        @object = object
      end
      attr_reader :object

      prepend(Scorpio.module_for_schema(schema_node))
    end
  end

  def self.class_for_schema(schema_node)
    CLASS_FOR_SCHEMA[schema_node]
  end

  def self.module_for_schema(schema_node_)
    Module.new.tap do |m|
      m.instance_exec(schema_node_) do |module_schema_node|
        raise(ArgumentError, module_schema_node.inspect) unless module_schema_node.is_a?(Scorpio::JSON::Node)
        raise(ArgumentError, module_schema_node.inspect) unless module_schema_node.content.is_a?(Hash)
        raise(ArgumentError, module_schema_node.inspect) unless module_schema_node['type'] == 'object'

        # Hash methods
        define_method(:each) { |&b| object.keys.each { |k| b.call(k, self[k]) } }
        include Enumerable
        # ones that don't look at the value - TODO incomplete
        %w(to_h empty? each_key keys has_key? key? length size).each do |method_name|
          define_method(method_name) { |*a, &b| object.public_send(method_name, *a, &b) }
        end
        # ones that do look at the value ... TODO implement
        %w(each_key values invert value? has_value?)

        define_method(:module_schema_node) do
          module_schema_node
        end

        define_method(:validate!) do
          ::JSON::Validator.validate!(module_schema_node.content, object)
        end

        define_method(:subschema_for_property) do |property|
          subschema_node = begin
            if schema_node['properties'] && schema_node['properties'][property]
              schema_node['properties'][property]
            else
              if schema_node['patternProperties']
                _, pattern_schema_node = schema_node['patternProperties'].detect do |pattern, _|
                  property =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                end
              end
              if pattern_schema_node
                pattern_schema_node
              else
                if schema_node['additionalProperties']
                  schema_node['additionalProperties']
                else
                  nil
                end
              end
            end
          end
        end

        define_method(:[]) do |property_name|
          @object_mapped ||= {}
          @object_mapped[property_name] ||= begin

            match_schema = proc do |schema_node, object|
              if schema_node['oneOf']
                matched = schema_node['oneOf'].map(&:deref).detect do |oneof|
                  ::JSON::Validator.validate(oneof.document, object, fragment: oneof.fragment)
                end
                matched || schema_node
              else
                schema_node
              end
            end

            property_schema_node = subschema_for_property(property_name)
            if property_schema_node && property_schema_node['type'] && property_schema_node['type'] == 'object' && object[property_name].is_a?(Hash)
              schema_node = match_schema.call(property_schema_node, object[property_name])
              Scorpio.class_for_schema(schema_node).new(object[property_name])
            elsif property_schema_node && property_schema_node['type'] && property_schema_node['type'] == 'array' && object[property_name].is_a?(Array)
              object[property_name].map do |e|
                schema_node = match_schema.call(property_schema_node['items'], e)
                if schema_node && schema_node['type'] && schema_node['type'] == 'object' && e.is_a?(Hash)
                  Scorpio.class_for_schema(schema_node).new(e)
                else
                  e
                end
              end
            else
              object[property_name]
            end
          end
        end

        (module_schema_node['properties'] || {}).each do |property_name, property_schema|
          define_method(property_name) do
            self[property_name]
          end
        end
      end
    end
  end
end
