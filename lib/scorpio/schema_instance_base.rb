require 'json'
require 'scorpio/typelike_modules'

module Scorpio
  # base class for representing an instance of an instance described by a schema
  class SchemaInstanceBase
    include Memoize

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

    def initialize(instance)
      unless respond_to?(:schema)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #schema. please use Scorpio.class_for_schema")
      end

      self.instance = instance

      if schema.describes_hash? && @instance.is_a?(Scorpio::JSON::HashNode)
        extend SchemaInstanceBaseHash
      elsif schema.describes_array? && @instance.is_a?(Scorpio::JSON::ArrayNode)
        extend SchemaInstanceBaseArray
      end
      # certain methods need to be redefined after we are extended by Enumerable
      extend OverrideFromExtensions
    end

    module OverrideFromExtensions
      def as_json
        Typelike.as_json(instance)
      end
    end

    attr_reader :instance

    def deref
      derefed = instance.deref
      if derefed.object_id == instance.object_id
        self
      else
        self.class.new(derefed)
      end
    end

    def modified_copy(&block)
      modified_instance = instance.modified_copy(&block)
      self.class.new(modified_instance)
    end

    def fragment
      instance.fragment
    end

    def fully_validate
      schema.fully_validate(instance)
    end
    def validate
      schema.validate(instance)
    end
    def validate!
      schema.validate!(instance)
    end
    def inspect
      "\#<#{self.class.inspect} #{instance.inspect}>"
    end
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.inspect}"
        group_sub {
          nest(2) {
            breakable ' '
            pp obj.instance
          }
        }
        breakable ''
        text '>'
      end
    end

    def object_group_text
      instance.class.inspect + ' ' + instance.object_group_text
    end

    def fingerprint
      {class: self.class, instance: instance}
    end
    include FingerprintHash

    private
    def instance=(thing)
      clear_memo(:[])
      if instance_variable_defined?(:@instance)
        if @instance.class != thing.class
          raise(Scorpio::Bug, "will not accept instance of different class #{thing.class} to current instance class #{@instance.class} on #{self.class.inspect}")
        end
      end
      if thing.is_a?(SchemaInstanceBase)
        warn "assigning instance to a SchemaInstanceBase instance is incorrect. received: #{thing.pretty_inspect.chomp}"
        @instance = Scorpio.deep_stringify_symbol_keys(thing.instance)
      elsif thing.is_a?(Scorpio::JSON::Node)
        @instance = Scorpio.deep_stringify_symbol_keys(thing)
      else
        @instance = Scorpio::JSON::Node.new_by_type(Scorpio.deep_stringify_symbol_keys(thing), [])
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
          Class.new(SchemaInstanceBase).instance_exec(schema_) do |schema|
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
          define_method(:schema) { schema }
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
            instance_method_modules = [m, SchemaInstanceBase, SchemaInstanceBaseArray, SchemaInstanceBaseHash, SchemaInstanceBase::OverrideFromExtensions]
            instance_methods = instance_method_modules.map do |mod|
              mod.instance_methods + mod.private_instance_methods
            end.inject(Set.new, &:|)
            accessors_to_define = schema.described_hash_property_names.map(&:to_s) - instance_methods.map(&:to_s)
            accessors_to_define.each do |property_name|
              define_method(property_name) do
                if respond_to?(:[])
                  self[property_name]
                else
                  raise(NoMethodError, "instance does not respond to []; cannot call reader `#{property_name}' for: #{pretty_inspect.chomp}")
                end
              end
              define_method("#{property_name}=") do |value|
                if respond_to?(:[]=)
                  self[property_name] = value
                else
                  raise(NoMethodError, "instance does not respond to []=; cannot call writer `#{property_name}=' for: #{pretty_inspect.chomp}")
                end
              end
            end
          end
        end
      end
    end
  end

  module SchemaInstanceBaseHash
    # Hash methods
    def each
      return to_enum(__method__) { instance.size } unless block_given?
      instance.each_key { |k| yield(k, self[k]) }
      self
    end

    def to_hash
      inject({}) { |h, (k, v)| h[k] = v; h }
    end

    include Hashlike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| instance.public_send(method_name, *a, &b) }
    end

    def [](property_name_)
      memoize(:[], property_name_) do |property_name|
        begin
          property_schema = schema.subschema_for_property(property_name)
          property_schema = property_schema && property_schema.match_to_instance(instance[property_name])

          if property_schema && instance[property_name].is_a?(JSON::Node)
            Scorpio.class_for_schema(property_schema).new(instance[property_name])
          else
            instance[property_name]
          end
        end
      end
    end

    def []=(property_name, value)
      self.instance = instance.modified_copy do |hash|
        hash.merge(property_name => value)
      end
    end
  end

  module SchemaInstanceBaseArray
    def each
      return to_enum(__method__) { instance.size } unless block_given?
      instance.each_index { |i| yield(self[i]) }
      self
    end

    def to_ary
      to_a
    end

    include Arraylike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| instance.public_send(method_name, *a, &b) }
    end

    def [](i_)
      memoize(:[], i_) do |i|
        begin
          index_schema = schema.subschema_for_index(i)
          index_schema = index_schema && index_schema.match_to_instance(instance[i])

          if index_schema && instance[i].is_a?(JSON::Node)
            Scorpio.class_for_schema(index_schema).new(instance[i])
          else
            instance[i]
          end
        end
      end
    end
    def []=(i, value)
      self.instance = instance.modified_copy do |ary|
        ary.each_with_index.map do |el, ary_i|
          ary_i == i ? value : el
        end
      end
    end
  end
end
