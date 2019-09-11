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
      # is the constant JSI::SchemaClasses::{self.schema_classes_const_name} defined?
      # (if so, we will prefer to use something more human-readable than that ugly mess.)
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
        name = 'X' + name unless name[/\A[a-zA-Z]/]
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

    # NOINSTANCE is a magic value passed to #initialize when instantiating a JSI
    # from a document and JSON Pointer.
    NOINSTANCE = Object.new.tap { |o| [:inspect, :to_s].each(&(-> (s, m) { o.define_singleton_method(m) { s } }.curry.([JSI::Base.name, 'NOINSTANCE'].join('::')))) }

    # initializes this JSI from the given instance - instance is most commonly
    # a parsed JSON document consisting of Hash, Array, or sometimes a basic
    # type, but this is in no way enforced and a JSI may wrap any object.
    #
    # @param instance [Object] the JSON Schema instance being represented
    # @param jsi_document [Object] for internal use. the instance may be specified as a
    #   node in the `jsi_document` param, pointed to by `jsi_ptr`. the param `instance`
    #   MUST be `NOINSTANCE` to use the jsi_document + jsi_ptr form. `jsi_document` MUST
    #   NOT be passed if `instance` is anything other than `NOINSTANCE`.
    # @param jsi_ptr [JSI::JSON::Pointer] for internal use. a JSON pointer specifying
    #   the path of this instance in the `jsi_document` param. `jsi_ptr` must be passed
    #   iff `jsi_document` is passed, i.e. when `instance` is `NOINSTANCE`
    # @param ancestor_jsi [JSI::Base] for internal use, specifies an ancestor_jsi
    #   from which this JSI originated to calculate #parents
    def initialize(instance, jsi_document: nil, jsi_ptr: nil, ancestor_jsi: nil)
      unless respond_to?(:schema)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #schema. please use JSI.class_for_schema")
      end

      if instance.is_a?(JSI::Base)
        raise(TypeError, "assigning another JSI::Base instance to #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      elsif instance.is_a?(JSI::Schema)
        raise(TypeError, "assigning a schema to #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      end

      if instance == NOINSTANCE
        @jsi_document = jsi_document
        unless jsi_ptr.is_a?(JSI::JSON::Pointer)
          raise(TypeError, "jsi_ptr must be a JSI::JSON::Pointer; got: #{jsi_ptr.inspect}")
        end
        @jsi_ptr = jsi_ptr
      else
        raise(Bug, 'incorrect usage') if jsi_document || jsi_ptr || ancestor_jsi
        @jsi_document = instance
        @jsi_ptr = JSI::JSON::Pointer.new([])
      end
      if ancestor_jsi
        if !ancestor_jsi.is_a?(JSI::Base)
          raise(TypeError, "ancestor_jsi must be a JSI::Base; got: #{ancestor_jsi.inspect}")
        end
        if !ancestor_jsi.jsi_ptr.contains?(@jsi_ptr)
          raise(Bug, "ancestor_jsi ptr #{ancestor_jsi.jsi_ptr.inspect} is not ancestor of #{@jsi_ptr.inspect}")
        end
      end
      @ancestor_jsi = ancestor_jsi

      if self.jsi_instance.respond_to?(:to_hash)
        extend BaseHash
      elsif self.jsi_instance.respond_to?(:to_ary)
        extend BaseArray
      end
    end

    # document containing the instance of this JSI
    attr_reader :jsi_document

    # JSI::JSON::Pointer pointing to this JSI's instance within the jsi_document
    attr_reader :jsi_ptr

    # a JSI which is an ancestor_jsi of this
    attr_reader :ancestor_jsi

    # the instance of the json-schema
    def jsi_instance
      instance = @jsi_ptr.evaluate(@jsi_document)
      instance
    end

    alias_method :instance, :jsi_instance

    # each is overridden by BaseHash or BaseArray when appropriate. the base
    # #each is not actually implemented, along with all the methods of Enumerable.
    def each
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{instance.pretty_inspect.chomp}"
    end

    # an array of JSI instances above this one in the document. empty if this
    # JSI does not have a known ancestor.
    #
    # @return [Array<JSI::Base>]
    def parent_jsis
      ancestor_jsi = @ancestor_jsi || self
      parent = ancestor_jsi

      (ancestor_jsi.jsi_ptr.reference_tokens.size...self.jsi_ptr.reference_tokens.size).map do |i|
        parent.tap do
          parent = parent[self.jsi_ptr.reference_tokens[i]]
        end
      end.reverse
    end

    # the immediate parent of this JSI. nil if there is no parent.
    #
    # @return [JSI::Base, nil]
    def parent_jsi
      parent_jsis.first
    end

    # @deprecated
    alias_method :parents, :parent_jsis
    # @deprecated
    alias_method :parent, :parent_jsi

    # if this JSI is a $ref then the $ref is followed. otherwise this JSI
    # is returned.
    #
    # @return [JSI::Base, self]
    def deref
      jsi_ptr_deref = @jsi_ptr.deref(@jsi_document)
      if jsi_ptr_deref == @jsi_ptr
        self
      else
        self.class.new(Base::NOINSTANCE, jsi_document: @jsi_document, jsi_ptr: jsi_ptr_deref, ancestor_jsi: @ancestor_jsi)
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
      modified_document = @jsi_ptr.modified_document_copy(@jsi_document, &block)
      self.class.new(Base::NOINSTANCE, jsi_document: modified_document, jsi_ptr: @jsi_ptr, ancestor_jsi: @ancestor_jsi)
    end

    # @return [String] the fragment representation of a pointer to this JSI's instance within its document
    def fragment
      @jsi_ptr.fragment
    end

    # @return [Array<String>] array of schema validation error messages for this instance
    def fully_validate
      schema.fully_validate_instance(instance)
    end

    # @return [true, false] whether the instance validates against its schema
    def validate
      schema.validate_instance(instance)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate a valid instance.
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors
    def validate!
      schema.validate_instance!(instance)
    end

    def dup
      modified_copy(&:dup)
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
      instance.respond_to?(:object_group_text) ? instance.object_group_text : instance.class.inspect
    end

    # @return [Object] a jsonifiable representation of the instance
    def as_json(*opt)
      Typelike.as_json(instance, *opt)
    end

    # @return [Object] an opaque fingerprint of this JSI for FingerprintHash. JSIs are equal
    #   if their instances are equal, and if the JSIs are of the same JSI class or subclass.
    def fingerprint
      {class: jsi_class, jsi_document: jsi_document, jsi_ptr: jsi_ptr}
    end
    include FingerprintHash

    private

    # assigns a subscript, unwrapping a JSI if given.
    # @param subscript [Object] the bit between the [ and ]
    # @param value [JSI::Base, Object] the value to be assigned
    def subscript_assign(subscript, value)
      clear_memo(:[])
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
      jsi_instance_hash_pubsend(:each_key) { |k| yield(k, self[k]) }
      self
    end

    # @return [Hash] a hash in which each key is a key of the instance hash and
    #   each value is the result of self[key] (see #[]).
    def to_hash
      {}.tap { |h| each_key { |k| h[k] = self[k] } }
    end

    include Hashlike

    # @param method_name [String, Symbol]
    # @param *a, &b are passed to the invocation of method_name
    # @return [Object] the result of calling method method_name on the instance or its #to_hash
    def jsi_instance_hash_pubsend(method_name, *a, &b)
      if instance.respond_to?(method_name)
        instance.public_send(method_name, *a, &b)
      else
        instance.to_hash.public_send(method_name, *a, &b)
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_hash)
    SAFE_KEY_ONLY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        jsi_instance_hash_pubsend(method_name, *a, &b)
      end
    end

    # @param property_name [String, Object] the property name to subscript
    # @return [JSI::Base, Object] the instance's subscript value at the given
    #   key property_name_. if there is a subschema defined for that property
    #   on this JSI's schema, returns the instance's subscript as a JSI
    #   instiation of that subschema.
    def [](property_name)
      memoize(:[], property_name, jsi_instance_sub(property_name), jsi_instance_hash_pubsend(:key?, property_name)) do |property_name_, instance_property_value, instance_property_key|
        begin
          property_schema = schema.subschema_for_property(property_name_)
          property_schema = property_schema && property_schema.match_to_instance(instance_property_value)

          if !instance_property_key && property_schema && property_schema.schema_object.key?('default')
            # use the default value
            default = property_schema.schema_object['default']
            if default.respond_to?(:to_hash) || default.respond_to?(:to_ary)
              class_for_schema(property_schema).new(default, ancestor_jsi: @ancestor_jsi || self)
            else
              default
            end
          elsif property_schema && (instance_property_value.respond_to?(:to_hash) || instance_property_value.respond_to?(:to_ary))
            class_for_schema(property_schema).new(Base::NOINSTANCE, jsi_document: @jsi_document, jsi_ptr: @jsi_ptr[property_name_], ancestor_jsi: @ancestor_jsi || self)
          else
            instance_property_value
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

    private

    # @param token [String, Object]
    # @return [Object]
    def jsi_instance_sub(token)
      jsi_instance_hash_pubsend(:[], token)
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
      jsi_instance_ary_pubsend(:each_index) { |i| yield(self[i]) }
      self
    end

    # @return [Array] an array, the same size as the instance, in which the
    #   element at each index is the result of self[index] (see #[])
    def to_ary
      to_a
    end

    include Arraylike

    # @param method_name [String, Symbol]
    # @param *a, &b are passed to the invocation of method_name
    # @return [Object] the result of calling method method_name on the instance or its #to_ary
    def jsi_instance_ary_pubsend(method_name, *a, &b)
      if instance.respond_to?(method_name)
        instance.public_send(method_name, *a, &b)
      else
        instance.to_ary.public_send(method_name, *a, &b)
      end
    end

    # methods that don't look at the value; can skip the overhead of #[] (invoked by #to_a).
    # we override these methods from Arraylike
    SAFE_INDEX_ONLY_METHODS.each do |method_name|
      define_method(method_name) do |*a, &b|
        jsi_instance_ary_pubsend(method_name, *a, &b)
      end
    end

    # @param i [Integer] the array index to subscript
    # @return [JSI::Base, Object] the instance's subscript value at the given index
    #   i. if there is a subschema defined for that index on this JSI's schema,
    #   returns the instance's subscript as a JSI instiation of that subschema.
    def [](i)
      memoize(:[], i, jsi_instance_sub(i), jsi_instance_ary_pubsend(:each_index).to_a.include?(i)) do |i_, instance_idx_value, i_in_range|
        begin
          index_schema = schema.subschema_for_index(i_)
          index_schema = index_schema && index_schema.match_to_instance(instance_idx_value)

          if !i_in_range && index_schema && index_schema.schema_object.key?('default')
            # use the default value
            default = index_schema.schema_object['default']
            if default.respond_to?(:to_hash) || default.respond_to?(:to_ary)
              class_for_schema(index_schema).new(default, ancestor_jsi: @ancestor_jsi || self)
            else
              default
            end
          elsif index_schema && (instance_idx_value.respond_to?(:to_hash) || instance_idx_value.respond_to?(:to_ary))
            class_for_schema(index_schema).new(Base::NOINSTANCE, jsi_document: @jsi_document, jsi_ptr: @jsi_ptr[i_], ancestor_jsi: @ancestor_jsi || self)
          else
            instance_idx_value
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

    private

    # @param token [Integer]
    # @return [Object]
    def jsi_instance_sub(token)
      jsi_instance_ary_pubsend(:[], token)
    end
  end
end
