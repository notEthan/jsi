require 'hana'
require 'json'
require 'json-schema'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
  end

  CLASS_FOR_SCHEMA = Hash.new do |h, (schema_, document_)|
    h[[schema_, document_]] = Class.new(SchemaObjectBase).instance_exec(schema_, document_) do |schema, document|
      define_singleton_method(:class_schema) { schema }
      define_singleton_method(:document) { document }
      define_method(:class_schema) { schema }
      define_method(:document) { document }

      define_method(:initialize) do |object|
        @object = object
      end
      attr_reader :object

      prepend(Scorpio.module_for_schema(schema))
    end
  end

  def self.class_for_schema(schema, document)
    CLASS_FOR_SCHEMA[[schema, document]]
  end

  def self.module_for_schema(schema_)
    Module.new.tap do |m|
      m.instance_exec(schema_) do |module_schema|
        raise(ArgumentError, module_schema.inspect) unless module_schema.is_a?(Hash)
        raise(ArgumentError, module_schema.inspect) unless module_schema['type'] == 'object'

        define_method(:each) { |&b| object.keys.each { |k| b.call(k, self[k]) } }
        include Enumerable

        define_method(:module_schema) do
          module_schema
        end

        define_method(:validate!) do
          JSON::Validator.validate!(module_schema, object)
        end

        define_method(:deref_schema) do |schema_to_deref|
          if schema_to_deref && schema_to_deref['$ref']
            if schema_to_deref['$ref'] =~ /\A#/
              path = $'
              pointer = Hana::Pointer.new(path)
              pointer.eval(document)
            elsif document['schemas'] && document['schemas'][schema_to_deref['$ref']]
              document['schemas'][schema_to_deref['$ref']]
            else
              # TODO? store hash mapping schema['$ref'] -> schema ... or use json validator's cache?
              schema_to_deref
            end
          else
            schema_to_deref
          end
        end

        define_method(:subschema_for_property) do |property|
          subschema = begin
            if module_schema['properties'] && module_schema['properties'][property]
              module_schema['properties'][property]
            else
              if module_schema['patternProperties']
                _, pattern_schema = module_schema['patternProperties'].detect do |pattern, _|
                  property =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                end
              end
              if pattern_schema
                pattern_schema
              else
                if module_schema['additionalProperties']
                  module_schema['additionalProperties']
                else
                  nil
                end
              end
            end
          end
          deref_schema(subschema)
        end

        define_method(:[]) do |property_name|
          property_schema = subschema_for_property(property_name)
          if property_schema && property_schema['type'] == 'object' && object[property_name].is_a?(Hash)
            Scorpio.class_for_schema(property_schema, document).new(object[property_name])
          elsif property_schema && property_schema['type'] == 'array' && object[property_name].is_a?(Array)
            object[property_name].map do |e|
              if property_schema['items'] && property_schema['items']['type'] == 'object' && e.is_a?(Hash)
                Scorpio.class_for_schema(property_schema['items'], document).new(e)
              else
                e
              end
            end
          else
            object[property_name]
          end
        end

        (module_schema['properties'] || []).each do |property_name, property_schema|
          define_method(property_name) do
            self[property_name]
          end
        end
      end
    end
  end
end
