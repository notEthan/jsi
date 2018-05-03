require 'json'
require 'scorpio/typelike_modules'

module Scorpio
  # base class for representing an instance of an object described by a schema
  class SchemaObjectBase
    class << self
      def schema_id
        schema.schema_id
      end

      def inspect
        if !respond_to?(:schema)
          super
        elsif !name || name =~ /\AScorpio::SchemaClasses::/
          %Q(#{SchemaClasses.inspect}[#{schema_id.inspect}])
        else
          %Q(#{name} (#{schema_id}))
        end
      end

      def schema_classes_const_name
        name = schema.schema_id.gsub(/[^\w]/, '_')
        name = 'X' + name unless name[/\A[a-zA-Z_]/]
        name = name[0].upcase + name[1..-1]
        name
      end

      def name
        unless super
          SchemaClasses.const_set(schema_classes_const_name, self)
        end
        super
      end
    end

    def initialize(object)
      unless respond_to?(:__schema__)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #__schema__. please use Scorpio.class_for_schema")
      end

      self.object = object

      if __schema__.describes_hash? && @object.is_a?(Scorpio::JSON::HashNode)
        extend SchemaObjectBaseHash
      elsif __schema__.describes_array? && @object.is_a?(Scorpio::JSON::ArrayNode)
        extend SchemaObjectBaseArray
      end
      # certain methods need to be redefined after we are extended by Enumerable
      extend OverrideFromExtensions
    end

    module OverrideFromExtensions
      def as_json
        Typelike.as_json(object)
      end
    end

    attr_reader :object

    def deref
      derefed = object.deref
      if derefed.object_id == object.object_id
        self
      else
        self.class.new(derefed)
      end
    end

    def modified_copy(&block)
      modified_object = object.modified_copy(&block)
      self.class.new(modified_object)
    end

    def fragment
      object.fragment
    end

    def fully_validate
      __schema__.fully_validate(object)
    end
    def validate
      __schema__.validate(object)
    end
    def validate!
      __schema__.validate!(object)
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
      if instance_variable_defined?(:@object)
        if @object.class != thing.class
          raise(Scorpio::Bug, "will not accept object of different class #{thing.class} to current object class #{@object.class} on #{self.class.inspect}")
        end
      end
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
    def self.[](schema_id)
      @classes_by_id[schema_id]
    end
    @classes_by_id = {}
  end

  def self.class_for_schema(schema_object)
    if schema_object.is_a?(Scorpio::Schema)
      schema__ = schema_object
    else
      schema__ = Scorpio::Schema.new(schema_object)
    end

    memoize(:class_for_schema, schema__) do |schema_|
      begin
        begin
          Class.new(SchemaObjectBase).instance_exec(schema_) do |schema|
            begin
              include(Scorpio.module_for_schema(schema))

              SchemaClasses.instance_exec(self) { |klass| @classes_by_id[klass.schema_id] = klass }

              self
            end
          end
        end
      end
    end
  end

  def self.module_for_schema(schema_object)
    if schema_object.is_a?(Scorpio::Schema)
      schema__ = schema_object
    else
      schema__ = Scorpio::Schema.new(schema_object)
    end

    memoize(:module_for_schema, schema__) do |schema_|
      Module.new.tap do |m|
        m.instance_exec(schema_) do |schema|
          define_method(:__schema__) { schema }
          define_singleton_method(:schema) { schema }
          define_singleton_method(:included) do |includer|
            includer.send(:define_singleton_method, :schema) { schema }
          end

          define_singleton_method(:schema_id) do
            schema.schema_id
          end
          define_singleton_method(:inspect) do
            %Q(#<Module for Schema: #{schema_id}>)
          end

          if schema.describes_hash?
            instance_method_modules = [m, SchemaObjectBase, SchemaObjectBaseArray, SchemaObjectBaseHash, SchemaObjectBase::OverrideFromExtensions]
            instance_methods = instance_method_modules.map do |mod|
              mod.instance_methods + mod.private_instance_methods
            end.inject(Set.new, &:|)
            accessors_to_define = schema.described_hash_property_names.map(&:to_s) - instance_methods.map(&:to_s)
            accessors_to_define.each do |property_name|
              define_method(property_name) do
                if respond_to?(:[])
                  self[property_name]
                else
                  raise(NoMethodError, "object does not respond to []; cannot call reader `#{property_name}' for: #{pretty_inspect.chomp}")
                end
              end
              define_method("#{property_name}=") do |value|
                if respond_to?(:[]=)
                  self[property_name] = value
                else
                  raise(NoMethodError, "object does not respond to []=; cannot call writer `#{property_name}=' for: #{pretty_inspect.chomp}")
                end
              end
            end
          end
        end
      end
    end
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
          property_schema = __schema__.subschema_for_property(property_name)
          property_schema = property_schema && property_schema.match_to_object(object[property_name])

          if property_schema && object[property_name].is_a?(JSON::Node)
            Scorpio.class_for_schema(property_schema).new(object[property_name])
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
          index_schema = __schema__.subschema_for_index(i)
          index_schema = index_schema && index_schema.match_to_object(object[i])

          if index_schema && object[i].is_a?(JSON::Node)
            Scorpio.class_for_schema(index_schema).new(object[i])
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
end
