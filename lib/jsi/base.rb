require 'json'
require 'jsi/typelike_modules'

module JSI
  # base class for representing an instance of an instance described by a schema
  class Base
    include Memoize
    include Enumerable

    class << self
      def schema_id
        schema.schema_id
      end

      def inspect
        if !respond_to?(:schema)
          super
        elsif !name || name =~ /\AJSI::SchemaClasses::/
          %Q(#{SchemaClasses.inspect}[#{schema_id.inspect}])
        else
          %Q(#{name} (#{schema_id}))
        end
      end
      def to_s
        if !respond_to?(:schema)
          super
        elsif !name || name =~ /\AJSI::SchemaClasses::/
          %Q(#{SchemaClasses.inspect}[#{schema_id.inspect}])
        else
          name
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

    def initialize(instance, origin: nil)
      unless respond_to?(:schema)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #schema. please use JSI.class_for_schema")
      end

      @origin = origin || self
      self.instance = instance

      if @instance.is_a?(JSI::JSON::HashNode)
        extend BaseHash
      elsif @instance.is_a?(JSI::JSON::ArrayNode)
        extend BaseArray
      end
    end

    attr_reader :instance

    # each is overridden by BaseHash or BaseArray when appropriate. the base
    # #each is not actually implemented, along with all the methods of Enumerable.
    def each
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{instance.pretty_inspect.chomp}"
    end

    def parents
      parent = @origin
      (@origin.instance.path.size...self.instance.path.size).map do |i|
        parent.tap do
          parent = parent[self.instance.path[i]]
        end
      end.reverse
    end
    def parent
      parents.first
    end

    def deref
      derefed = instance.deref
      if derefed.object_id == instance.object_id
        self
      else
        self.class.new(derefed, origin: @origin)
      end
    end

    def modified_copy(&block)
      modified_instance = instance.modified_copy(&block)
      self.class.new(modified_instance, origin: @origin)
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
      "\#<#{self.class.to_s} #{instance.inspect}>"
    end
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.to_s}"
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
      instance.object_group_text
    end

    def as_json(*opt)
      Typelike.as_json(instance, *opt)
    end

    def fingerprint
      {class: self.class, instance: instance}
    end
    include FingerprintHash

    private
    def instance=(thing)
      if instance_variable_defined?(:@instance)
        raise(JSI::Bug, "overwriting instance is not supported")
      end
      if thing.is_a?(Base)
        warn "assigning instance to a Base instance is incorrect. received: #{thing.pretty_inspect.chomp}"
        @instance = thing.instance
      elsif thing.is_a?(JSI::JSON::Node)
        @instance = thing
      else
        @instance = JSI::JSON::Node.new_doc(thing)
      end
    end

    def subscript_assign(subscript, value)
      clear_memo(:[], subscript)
      if value.is_a?(Base)
        instance[subscript] = value.instance
      else
        instance[subscript] = value
      end
    end
  end

  # this module is just a namespace for schema classes.
  module SchemaClasses
    extend Memoize
    def self.[](schema_id)
      @classes_by_id[schema_id]
    end
    @classes_by_id = {}
  end

  def SchemaClasses.class_for_schema(schema_object)
    if schema_object.is_a?(JSI::Schema)
      schema__ = schema_object
    else
      schema__ = JSI::Schema.new(schema_object)
    end

    memoize(:class_for_schema, schema__) do |schema_|
      begin
        begin
          Class.new(Base).instance_exec(schema_) do |schema|
            begin
              include(JSI::SchemaClasses.module_for_schema(schema))

              SchemaClasses.instance_exec(self) { |klass| @classes_by_id[klass.schema_id] = klass }

              self
            end
          end
        end
      end
    end
  end

  def SchemaClasses.module_for_schema(schema_object)
    if schema_object.is_a?(JSI::Schema)
      schema__ = schema_object
    else
      schema__ = JSI::Schema.new(schema_object)
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

          instance_method_modules = [m, Base, BaseArray, BaseHash]
          instance_methods = instance_method_modules.map do |mod|
            mod.instance_methods + mod.private_instance_methods
          end.inject(Set.new, &:|)
          accessors_to_define = schema.described_object_property_names.map(&:to_s) - instance_methods.map(&:to_s)
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

  module BaseHash
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
            JSI.class_for_schema(property_schema).new(instance[property_name], origin: @origin)
          else
            instance[property_name]
          end
        end
      end
    end
    def []=(property_name, value)
      subscript_assign(property_name, value)
    end
  end

  module BaseArray
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
            JSI.class_for_schema(index_schema).new(instance[i], origin: @origin)
          else
            instance[i]
          end
        end
      end
    end
    def []=(i, value)
      subscript_assign(i, value)
    end
  end
end
