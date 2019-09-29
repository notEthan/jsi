require 'json'
require 'jsi/typelike_modules'

module JSI
  # the base class for representing and instantiating a JSON Schema.
  #
  # a class inheriting from JSI::Base represents a JSON Schema. an instance of
  # that class represents a JSON schema instance.
  #
  # as such, JSI::Base itself is not intended to be instantiated - subclasses
  # are dynamically created for schemas using {JSI.class_for_schema}, and these
  # are what are used to instantiate and represent JSON schema instances.
  class Base
    include Memoize
    include Enumerable

    class << self
      attr_accessor :in_schema_classes

      # @return [String] absolute schema_id of the schema this class represents.
      #   see {Schema#schema_id}.
      def schema_id
        schema.schema_id
      end

      # @return [String] a string representing the class, with schema_id
      def inspect
        name # see #name for side effects
        if !respond_to?(:schema)
          super
        elsif in_schema_classes
          %Q(#{SchemaClasses.inspect}[#{schema_id.inspect}])
        elsif !name
          %Q(#<Class for Schema: #{schema_id}>)
        else
          %Q(#{name} (#{schema_id}))
        end
      end

      # @return [String] a string representing the class - a class name if one
      #   was explicitly defined, otherwise a reference to JSI::SchemaClasses
      def to_s
        if !respond_to?(:schema)
          super
        elsif !name || name =~ /\AJSI::SchemaClasses::/
          %Q(#{SchemaClasses.inspect}[#{schema_id.inspect}])
        else
          name
        end
      end

      # @return [String] a name for a constant for this class, generated from the
      #   schema_id. only used if the class is not assigned to another constant.
      def schema_classes_const_name
        name = schema.schema_id.gsub(/[^\w]/, '_')
        name = 'X' + name unless name[/\A[a-zA-Z_]/]
        name = name[0].upcase + name[1..-1]
        name
      end

      # @return [String] a constant name of this class
      def name
        unless super || SchemaClasses.const_defined?(schema_classes_const_name)
          SchemaClasses.const_set(schema_classes_const_name, self)
          self.in_schema_classes = true
        end
        super
      end
    end

    # initializes this JSI from the given instance. the instance will be
    # wrapped as a {JSI::JSON::Node JSI::JSON::Node} (unless what you pass is
    # a Node already).
    #
    # @param instance [Object] the JSON Schema instance being represented
    # @param ancestor [JSI::Base] for internal use, specifies an ancestor
    #   from which this JSI originated to calculate #parents
    def initialize(instance, ancestor: nil)
      unless respond_to?(:schema)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #schema. please use JSI.class_for_schema")
      end

      @ancestor = ancestor || self
      self.instance = instance

      if @instance.is_a?(JSI::JSON::HashNode)
        extend BaseHash
      elsif @instance.is_a?(JSI::JSON::ArrayNode)
        extend BaseArray
      end
    end

    # the instance of the json-schema. this is a JSI::JSON::Node.
    attr_reader :instance

    # a JSI which is an ancestor of this
    attr_reader :ancestor

    # each is overridden by BaseHash or BaseArray when appropriate. the base
    # #each is not actually implemented, along with all the methods of Enumerable.
    def each
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{instance.pretty_inspect.chomp}"
    end

    # an array of JSI instances above this one in the document. empty if this
    # JSI is at the root or was instantiated from a source that does not have
    # a document (e.g. a plain hash or array).
    #
    # @return [Array<JSI::Base>]
    def parents
      parent = @ancestor
      (@ancestor.instance.pointer.reference_tokens.size...self.instance.pointer.reference_tokens.size).map do |i|
        parent.tap do
          parent = parent[self.instance.pointer.reference_tokens[i]]
        end
      end.reverse
    end

    # the immediate parent of this JSI. nil if no parent(s) are known.
    #
    # @return [JSI::Base, nil]
    def parent
      parents.first
    end

    # if this JSI is a $ref then the $ref is followed. otherwise this JSI
    # is returned.
    #
    # @return [JSI::Base, self]
    def deref
      derefed = instance.deref
      if derefed.object_id == instance.object_id
        self
      else
        self.class.new(derefed, ancestor: @ancestor)
      end
    end

    # yields the content of the underlying instance. the block must result in
    # a modified copy of that (not destructively modifying the yielded content)
    # which will be used to instantiate a new instance of this JSI class with
    # the modified content.
    # @yield [Object] the content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [JSI::Base subclass the same as self] the modified copy of self
    def modified_copy(&block)
      modified_instance = instance.modified_copy(&block)
      self.class.new(modified_instance, ancestor: @ancestor)
    end

    def fragment
      instance.fragment
    end

    # @return [Array<String>] array of schema validation error messages for this instance
    def fully_validate
      schema.fully_validate(instance)
    end

    # @return [true, false] whether the instance validates against its schema
    def validate
      schema.validate(instance)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate a valid instance.
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors
    def validate!
      schema.validate!(instance)
    end

    # @return [String] a string representing this JSI, indicating its class
    #   and inspecting its instance
    def inspect
      "\#<#{self.class.to_s} #{instance.inspect}>"
    end

    # pretty-prints a representation this JSI to the given printer
    # @return [void]
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

    # @return [String] the instance's object_group_text
    def object_group_text
      instance.object_group_text
    end

    # @return [Object] a jsonifiable representation of the instance
    def as_json(*opt)
      Typelike.as_json(instance, *opt)
    end

    # @return [Object] an opaque fingerprint of this JSI for FingerprintHash. JSIs are equal
    #   if their instances are equal, and if the JSIs are of the same JSI class or subclass.
    def fingerprint
      {class: jsi_class, instance: instance}
    end
    include FingerprintHash

    private

    # assigns @instance to the given thing, raising if the thing is not appropriate for a JSI instance
    # @param thing [Object] a JSON schema instance for this class's schema
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

    # assigns a subscript, taking care of memoization and unwrapping a JSI if given.
    # @param subscript [Object] the bit between the [ and ]
    # @param value [JSI::Base, Object] the value to be assigned
    def subscript_assign(subscript, value)
      clear_memo(:[], subscript)
      if value.is_a?(Base)
        instance[subscript] = value.instance
      else
        instance[subscript] = value
      end
    end

    # this is an instance method in order to allow subclasses of JSI classes to
    # override it to point to other subclasses corresponding to other schemas.
    def class_for_schema(schema)
      JSI.class_for_schema(schema)
    end
  end

  # this module is just a namespace for schema classes.
  module SchemaClasses
    extend Memoize

    # JSI::SchemaClasses[schema_id] returns a class for the schema with the
    # given id, the same class as returned from JSI.class_for_schema.
    #
    # @param schema_id [String] absolute schema id as returned by {JSI::Schema#schema_id}
    # @return [Class subclassing JSI::Base] the class for that schema
    def self.[](schema_id)
      @classes_by_id[schema_id]
    end
    @classes_by_id = {}
  end

  # see {JSI.class_for_schema}
  def SchemaClasses.class_for_schema(schema_object)
    memoize(:class_for_schema, JSI::Schema.from_object(schema_object)) do |schema_|
      begin
        begin
          Class.new(Base).instance_exec(schema_) do |schema|
            begin
              include(JSI::SchemaClasses.module_for_schema(schema))

              jsi_class = self
              define_method(:jsi_class) { jsi_class }

              SchemaClasses.instance_exec(self) { |klass| @classes_by_id[klass.schema_id] = klass }

              self
            end
          end
        end
      end
    end
  end

  # a module for the given schema, with accessor methods for any object
  # property names the schema identifies. also has class and instance
  # methods called #schema to access the {JSI::Schema} this module
  # represents.
  #
  # accessor methods are defined on these modules so that methods can be
  # defined on {JSI.class_for_schema} classes without method redefinition
  # warnings. additionally, these overriding instance methods can call
  # `super` to invoke the normal accessor behavior.
  #
  # no property names that are the same as existing method names on the JSI
  # class will be defined. users should use #[] and #[]= to access properties
  # whose names conflict with existing methods.
  def SchemaClasses.module_for_schema(schema_object)
    memoize(:module_for_schema, JSI::Schema.from_object(schema_object)) do |schema_|
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

  # module extending a {JSI::Base} object when its instance is Hash-like (responds to #to_hash)
  module BaseHash
    # yields each key and value of this JSI.
    # each yielded key is the same as a key of the instance, and each yielded
    # value is the result of self[key] (see #[]).
    # returns an Enumerator if no block is given.
    # @yield [Object, Object] each key and value of this JSI hash
    # @return [self, Enumerator]
    def each
      return to_enum(__method__) { instance.size } unless block_given?
      instance.each_key { |k| yield(k, self[k]) }
      self
    end

    # @return [Hash] a hash in which each key is a key of the instance hash and
    #   each value is the result of self[key] (see #[]).
    def to_hash
      inject({}) { |h, (k, v)| h[k] = v; h }
    end

    include Hashlike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| instance.public_send(method_name, *a, &b) }
    end

    # @return [JSI::Base, Object] the instance's subscript value at the given
    #   key property_name_. if there is a subschema defined for that property
    #   on this JSI's schema, returns the instance's subscript as a JSI
    #   instiation of that subschema.
    def [](property_name_)
      memoize(:[], property_name_) do |property_name|
        begin
          property_schema = schema.subschema_for_property(property_name)
          property_schema = property_schema && property_schema.match_to_instance(instance[property_name])

          if !instance.key?(property_name) && property_schema && property_schema.schema_object.key?('default')
            # use the default value
            default = property_schema.schema_object['default']
            if default.respond_to?(:to_hash) || default.respond_to?(:to_ary)
              class_for_schema(property_schema).new(default, ancestor: @ancestor)
            else
              default
            end
          elsif property_schema && (instance[property_name].respond_to?(:to_hash) || instance[property_name].respond_to?(:to_ary))
            class_for_schema(property_schema).new(instance[property_name], ancestor: @ancestor)
          else
            instance[property_name]
          end
        end
      end
    end

    # assigns the given property name of the instance to the given value.
    # if the value is a JSI, its instance is assigned.
    # @param property_name [Object] this should generally be a String, but JSI
    #   does not enforce any constraint on it.
    # @param value [Object] the value to be assigned to the given subscript
    #   property_name
    def []=(property_name, value)
      subscript_assign(property_name, value)
    end
  end

  # module extending a {JSI::Base} object when its instance is Array-like (responds to #to_ary)
  module BaseArray
    # yields each element. each yielded element is the result of self[index]
    # for each index of the instance (see #[]).
    # returns an Enumerator if no block is given.
    # @yield [Object] each element of this JSI array
    # @return [self, Enumerator]
    def each
      return to_enum(__method__) { instance.size } unless block_given?
      instance.each_index { |i| yield(self[i]) }
      self
    end

    # @return [Array] an array, the same size as the instance, in which the
    #   element at each index is the result of self[index] (see #[])
    def to_ary
      to_a
    end

    include Arraylike

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
      define_method(method_name) { |*a, &b| instance.public_send(method_name, *a, &b) }
    end

    # @return [JSI::Base, Object] returns the instance's subscript value at the given index
    #   i_. if there is a subschema defined for that index on this JSI's schema,
    #   returns the instance's subscript as a JSI instiation of that subschema.
    # @param i_ the array index to subscript
    def [](i_)
      memoize(:[], i_) do |i|
        begin
          index_schema = schema.subschema_for_index(i)
          index_schema = index_schema && index_schema.match_to_instance(instance[i])

          if !instance.each_index.to_a.include?(i) && index_schema && index_schema.schema_object.key?('default')
            # use the default value
            default = index_schema.schema_object['default']
            if default.respond_to?(:to_hash) || default.respond_to?(:to_ary)
              class_for_schema(index_schema).new(default, ancestor: @ancestor)
            else
              default
            end
          elsif index_schema && (instance[i].respond_to?(:to_hash) || instance[i].respond_to?(:to_ary))
            class_for_schema(index_schema).new(instance[i], ancestor: @ancestor)
          else
            instance[i]
          end
        end
      end
    end

    # assigns the given index of the instance to the given value.
    # if the value is a JSI, its instance is assigned.
    # @param i [Object] the array index to assign
    # @param value [Object] the value to be assigned to the given subscript i
    def []=(i, value)
      subscript_assign(i, value)
    end
  end
end
