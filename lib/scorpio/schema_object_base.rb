require 'json'
require 'scorpio/typelike_modules'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
    def initialize(object)
      if object.is_a?(Scorpio::JSON::Node)
        @object = object
      else
        @object = Scorpio::JSON::Node.new_by_type(object, [])
      end
    end

    attr_reader :object

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

    def fingerprint
      {class: self.class, object: object}
    end
    include FingerprintHash
  end

  CLASS_FOR_SCHEMA = Hash.new do |h, schema_node_|
    h[schema_node_] = Class.new(SchemaObjectBase).instance_exec(schema_node_) do |schema_node|
      prepend(Scorpio.module_for_schema(schema_node))
    end
  end

  def self.class_for_schema(schema_node)
    schema_node = schema_node.object if schema_node.is_a?(Scorpio::SchemaObjectBase)
    CLASS_FOR_SCHEMA[schema_node.deref]
  end

  # this invokes methods of type-like modules (Arraylike, Hashlike) but only if the #object
  # is of the expected class. since the object may be anything - it will just not be a valid
  # instance of its schema - we can't assume that the methods on the Xlike modules will work
  # (e.g. trying to call #each_index on an #object that's not array-like)
  module SchemaObjectMightBeLike
    def inspect(*a, &b)
      if object.is_a?(expected_object_class)
        super
      else
        SchemaObjectBase.instance_method(:inspect).bind(self).call(*a, &b)
      end
    end
    def pretty_print(*a, &b)
      if object.is_a?(expected_object_class)
        super
      else
        SchemaObjectBase.instance_method(:pretty_print).bind(self).call(*a, &b)
      end
    end
  end
  module SchemaObjectBaseHash
    def expected_object_class
      Scorpio::JSON::HashNode
    end

    # Hash methods
    def each
      return to_enum(__method__) { object.size } unless block_given?
      object.each_key { |k| yield(k, self[k]) }
      self
    end
    include Enumerable

    def to_hash
      inject({}) { |h, (k, v)| h[k] = v; h }
    end

    include Hashlike
    include SchemaObjectMightBeLike

    # hash methods - define only those which do not modify the hash.

    # methods that don't look at the value; can skip the overhead of #[]
    key_methods = %w(each_key empty? include? has_key? key key? keys length member? size)
    key_methods.each do |method_name|
      define_method(method_name) { |*a, &b| object.public_send(method_name, *a, &b) }
    end

    # methods which use key and value
    hash_methods = %w(compact each_pair each_value fetch fetch_values has_value? invert
      rassoc reject select to_h transform_values value? values values_at)
    hash_methods.each do |method_name|
      define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
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

    def merge(other)
      # we want to strip the containers from this before we merge
      # this is kind of annoying. wish I had a better way.
      other_stripped = ycomb do |striprec|
        proc do |stripobject|
          stripobject = stripobject.object if stripobject.is_a?(Scorpio::SchemaObjectBase)
          stripobject = stripobject.content if stripobject.is_a?(Scorpio::JSON::Node)
          if stripobject.is_a?(Hash)
            stripobject.map { |k, v| {striprec.call(k) => striprec.call(v)} }.inject({}, &:update)
          elsif stripobject.is_a?(Array)
            stripobject.map(&striprec)
          elsif stripobject.is_a?(Symbol)
            stripobject.to_s
          elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| stripobject.is_a?(c) }
            stripobject
          else
            raise(TypeError, "bad (not jsonifiable) object: #{stripobject.pretty_inspect}")
          end
        end
      end.call(other)

      self.class.new(object.merge(other_stripped))
    end
  end

  module SchemaObjectBaseArray
    def expected_object_class
      Scorpio::JSON::ArrayNode
    end

    def each
      return to_enum(__method__) { object.size } unless block_given?
      object.each_index { |i| yield(self[i]) }
      self
    end
    include Enumerable

    def to_ary
      to_a
    end

    include Arraylike
    include SchemaObjectMightBeLike

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
          include SchemaObjectBaseHash

          module_schema.described_hash_property_names.each do |property_name|
            define_method(property_name) do
              self[property_name]
            end
          end
        elsif module_schema.describes_array?
          include SchemaObjectBaseArray
        end
      end
    end
  end
end
