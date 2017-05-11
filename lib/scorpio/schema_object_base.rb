require 'hana'
require 'json'
require 'json-schema'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
  end

  CLASS_FOR_SCHEMA = Hash.new do |h, (schema_, document_, schema_path_)|
    h[[schema_, document_, schema_path_]] = Class.new(SchemaObjectBase).instance_exec(schema_, document_, schema_path_) do |schema, document, schema_path|
      define_singleton_method(:class_schema) { schema }
      define_singleton_method(:document) { document }
      define_singleton_method(:schema_path) { schema_path }
      define_method(:class_schema) { schema }
      define_method(:document) { document }
      define_method(:schema_path) { schema_path }

      define_method(:initialize) do |object|
        @object = object
      end
      attr_reader :object

      prepend(Scorpio.module_for_schema(schema))
    end
  end

  def self.class_for_schema(schema, document, schema_path)
    CLASS_FOR_SCHEMA[[schema, document, schema_path]]
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

        define_method(:deref_schema) do |schema_to_deref, path|
          if schema_to_deref && schema_to_deref['$ref']
            if schema_to_deref['$ref'] =~ /\A#/
              path = $'
              pointer = Hana::Pointer.new(path)
              [pointer.eval(document), Hana::Pointer.parse(path)]
            elsif document['schemas'] && document['schemas'][schema_to_deref['$ref']]
              [document['schemas'][schema_to_deref['$ref']], ['schemas', schema_to_deref['$ref']]]
            else
              # TODO? store hash mapping schema['$ref'] -> schema ... or use json validator's cache?
              [schema_to_deref, path]
            end
          else
            [schema_to_deref, path]
          end
        end

        define_method(:subschema_for_property) do |property|
          subschema, path = begin
            if module_schema['properties'] && module_schema['properties'][property]
              [module_schema['properties'][property], schema_path + ['properties', property]]
            else
              if module_schema['patternProperties']
                pattern, pattern_schema = module_schema['patternProperties'].detect do |pattern, _|
                  property =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                end
              end
              if pattern_schema
                [pattern_schema, schema_path + ['patternProperties', pattern]]
              else
                if module_schema['additionalProperties']
                  [module_schema['additionalProperties'], schema_path + ['additionalProperties']]
                else
                  [nil, nil]
                end
              end
            end
          end
          deref_schema(subschema, path)
        end

        define_method(:pointer_path) do |*path|
          esc = {'^' => '^^', '~' => '~0', '/' => '~1'} # '/' => '^/' ?
          (path).map { |part| part.to_s.gsub(/[\^~\/]/) { |m| esc[m] } }.join("/")
        end
        define_method(:fragment) do |*path|
          "#/" + pointer_path(*path)
        end

        define_method(:[]) do |property_name|
          @object_mapped ||= {}
          @object_mapped[property_name] ||= begin

            match_schema = proc do |schema, schema_path, object|
              if schema['oneOf']
                matched, mi = schema['oneOf'].each_with_index.detect do |oneof, i|
                  JSON::Validator.validate(document, object, fragment: fragment(*schema_path, 'oneOf', i))
                end
                if matched
                  [matched, schema_path + ['oneOf', mi]]
                else
                  [schema, schema_path]
                end
              else
                [schema, schema_path]
              end
            end

            property_schema, property_schema_path = subschema_for_property(property_name)
            if property_schema && property_schema['type'] == 'object' && object[property_name].is_a?(Hash)
              schema, match_path = match_schema.call(property_schema, property_schema_path, object[property_name])
              Scorpio.class_for_schema(schema, document, match_path).new(object[property_name])
            elsif property_schema && property_schema['type'] == 'array' && object[property_name].is_a?(Array)
              item_schema, item_schema_path = deref_schema(property_schema['items'], property_schema_path + ['items'])
              object[property_name].map do |e|
                schema, schema_path = deref_schema(*match_schema.call(item_schema, item_schema_path, e))
                if schema && schema['type'] == 'object' && e.is_a?(Hash)
                  Scorpio.class_for_schema(schema, document, schema_path).new(e)
                else
                  e
                end
              end
            else
              object[property_name]
            end
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
