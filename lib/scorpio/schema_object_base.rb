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
        if object.is_a?(Scorpio::JSON::Node)
          @object = object
        else
          @object = Scorpio::JSON::Node.new_by_type(object, [])
        end
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
        define_method(:each) { |&b| object.each { |k, _| b.call(k, self[k]) } }
        include Enumerable
        # ones that don't look at the value - TODO incomplete
        %w(to_hash to_h empty? each_key keys has_key? key? length size).each do |method_name|
          define_method(method_name) { |*a, &b| object.content.public_send(method_name, *a, &b) }
        end
        # ones that do look at the value ... TODO implement
        %w(each_key values invert value? has_value?)
        define_method(:to_hash) do
          inject({}) { |h, (k, v)| h[k] = v; h }
        end

        # hash methods - define only those which do not modify the hash.

        # methods that don't look at the value; can skip the overhead of #[]
        key_methods = %w(each_key empty? include? has_key? key key? keys length member? size)
        key_methods.each do |method_name|
          define_method(method_name) { |*a, &b| object.public_send(method_name, *a, &b) }
        end

        # methods which use key and value
        hash_methods = %w(compact each_pair each_value fetch fetch_values has_value? invert
          merge rassoc reject select to_h transform_values value? values values_at)
        hash_methods.each do |method_name|
          define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
        end


        define_method(:module_schema_node) do
          module_schema_node
        end

        define_method(:fully_validate) do
          ::JSON::Validator.fully_validate(module_schema_node.document, object.content, fragment: module_schema_node.fragment)
        end
        define_method(:validate) do
          ::JSON::Validator.validate(module_schema_node.document, object.content, fragment: module_schema_node.fragment)
        end
        define_method(:validate!) do
          ::JSON::Validator.validate!(module_schema_node.document, object.content, fragment: module_schema_node.fragment)
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
              object = object.content if object.is_a?(Scorpio::JSON::Node)
              if schema_node && schema_node['oneOf']
                matched = schema_node['oneOf'].map(&:deref).detect do |oneof|
                  ::JSON::Validator.validate(oneof.document, object, fragment: oneof.fragment)
                end
                matched || schema_node
              else
                schema_node
              end
            end

            property_schema_node = match_schema.call(subschema_for_property(property_name), object[property_name])
            if property_schema_node && property_schema_node['type'] == 'object' && object.content[property_name].respond_to?(:to_hash)
              Scorpio.class_for_schema(property_schema_node).new(object[property_name])
            elsif property_schema_node && property_schema_node['type'] == 'array' && object.content[property_name].respond_to?(:to_ary)
              object[property_name].map do |e|
                item_schema_node = match_schema.call(property_schema_node['items'], e)
                if item_schema_node && item_schema_node['type'] == 'object' && e.respond_to?(:to_hash)
                  Scorpio.class_for_schema(item_schema_node).new(e)
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
