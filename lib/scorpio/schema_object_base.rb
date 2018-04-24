require 'json'
require 'scorpio/typelike_modules'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
    class << self
      def id
        module_schema.id
      end

      def inspect
        if !respond_to?(:__schema__)
          super
        elsif !name || name =~ /\AScorpio::SchemaClasses::/
          %Q(#{SchemaClasses.inspect}[#{id.inspect}])
        else
          %Q(#{name} (#{id}))
        end
      end
    end

    def initialize(object)
      self.object = object

      if module_schema.describes_hash? && @object.is_a?(Scorpio::JSON::HashNode)
        extend SchemaObjectBaseHash
      elsif module_schema.describes_array? && @object.is_a?(Scorpio::JSON::ArrayNode)
        extend SchemaObjectBaseArray
      end
      # as_json needs to be defined after we are extended by Enumerable
      define_singleton_method(:as_json) { Typelike.as_json(object) }
    end

    attr_reader :object

    def deref
      self.class.new(object.deref)
    end

    def modified_copy(&block)
      modified_object = object.modified_copy(&block)
      self.class.new(modified_object)
    end

    def fragment
      object.fragment
    end

    def fully_validate
      module_schema.fully_validate(object)
    end
    def validate
      module_schema.validate(object)
    end
    def validate!
      module_schema.validate!(object)
    end
    def inspect
      "\#<#{self.class.inspect} #{object.inspect}>"
    end
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.inspect}"
        group_sub {
          nest(2) {
            breakable ' '
            pp obj.object
          }
        }
        breakable ''
        text '>'
      end
    end

    def object_group_text
      object.class.inspect + ' ' + object.object_group_text
    end

    def fingerprint
      {class: self.class, object: object}
    end
    include FingerprintHash

    private
    def object=(thing)
      @object_mapped.clear if @object_mapped
      if thing.is_a?(SchemaObjectBase)
        warn "assigning object to a SchemaObjectBase instance is incorrect. received: #{thing.pretty_inspect.chomp}"
        @object = thing.object
      elsif thing.is_a?(Scorpio::JSON::Node)
        @object = thing
      else
        @object = Scorpio::JSON::Node.new_by_type(thing, [])
      end
    end
  end

  # this module is just a namespace for schema classes.
  module SchemaClasses
    def self.[](id)
      @classes_by_id[id]
    end
    @classes_by_id = {}
  end

  CLASS_FOR_SCHEMA = Hash.new do |h, schema_node_|
    h[schema_node_] = Class.new(SchemaObjectBase).instance_exec(schema_node_) do |schema_node|
      include(Scorpio.module_for_schema(schema_node))

      name = self.module_schema.id.gsub(/[^\w]/, '_')
      name = 'X' + name unless name[/\A[a-zA-Z_]/]
      name = name[0].upcase + name[1..-1]
      SchemaClasses.const_set(name, self)
      SchemaClasses.instance_exec(id, self) { |id_, klass| @classes_by_id[id_] = klass }

      self
    end
  end

  def self.class_for_schema(schema_node)
    schema_node = schema_node.object if schema_node.is_a?(Scorpio::SchemaObjectBase)
    CLASS_FOR_SCHEMA[schema_node.deref]
  end

  module SchemaObjectBaseHash
    # Hash methods
    def each
      return to_enum(__method__) { object.size } unless block_given?
      object.each_key { |k| yield(k, self[k]) }
      self
    end

    def to_hash
      inject({}) { |h, (k, v)| h[k] = v; h }
    end

    include Hashlike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| object.public_send(method_name, *a, &b) }
    end

    SAFE_MODIFIED_COPY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        modified_copy do |object_to_modify|
          object_to_modify.public_send(method_name, *a, &b)
        end
      end
    end

    def [](property_name_)
      @object_mapped ||= Hash.new do |hash, property_name|
        hash[property_name] = begin
          property_schema = module_schema.subschema_for_property(property_name)
          property_schema = property_schema && property_schema.match_to_object(object[property_name])

          if property_schema && object[property_name].is_a?(JSON::Node)
            Scorpio.class_for_schema(property_schema.schema_node).new(object[property_name])
          else
            object[property_name]
          end
        end
      end
      @object_mapped[property_name_]
    end

    def []=(property_name, value)
      self.object = object.modified_copy do |hash|
        hash.merge(property_name => value)
      end
    end
  end

  module SchemaObjectBaseArray
    def each
      return to_enum(__method__) { object.size } unless block_given?
      object.each_index { |i| yield(self[i]) }
      self
    end

    def to_ary
      to_a
    end

    include Arraylike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| object.public_send(method_name, *a, &b) }
    end

    SAFE_MODIFIED_COPY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        modified_copy do |object_to_modify|
          object_to_modify.public_send(method_name, *a, &b)
        end
      end
    end

    def [](i_)
      # it would make more sense for this to be an array here, but but Array doesn't have a nice memoizing
      # constructor, so it's a hash with integer keys
      @object_mapped ||= Hash.new do |hash, i|
        hash[i] = begin
          index_schema = module_schema.subschema_for_index(i)
          index_schema = index_schema && index_schema.match_to_object(object[i])

          if index_schema && object[i].is_a?(JSON::Node)
            Scorpio.class_for_schema(index_schema.schema_node).new(object[i])
          else
            object[i]
          end
        end
      end
      @object_mapped[i_]
    end
    def []=(i, value)
      self.object = object.modified_copy do |ary|
        ary.each_with_index.map do |el, ary_i|
          ary_i == i ? value : el
        end
      end
    end
  end

  def self.module_for_schema(schema_node_)
    Module.new.tap do |m|
      m.instance_exec(schema_node_) do |module_schema_node|
        unless module_schema_node.is_a?(Scorpio::JSON::Node)
          raise(ArgumentError, "expected instance of Scorpio::JSON::Node; got: #{module_schema_node.pretty_inspect.chomp}")
        end

        module_schema = Scorpio::Schema.new(module_schema_node)

        define_method(:module_schema) { module_schema }
        define_singleton_method(:module_schema) { module_schema }
        define_singleton_method(:included) do |includer|
          includer.send(:define_singleton_method, :module_schema) { module_schema }
        end

        if module_schema.describes_hash?
          module_schema.described_hash_property_names.each do |property_name|
            define_method(property_name) do
              self[property_name]
            end
            define_method("#{property_name}=") do |value|
              if respond_to?(:[]=)
                self[property_name] = value
              else
                raise(NoMethodError, "object does not respond to []=; cannot call accessor `#{property_name}=' for #{inspect}")
              end
            end
          end
        end
      end
    end
  end
end
