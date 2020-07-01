# frozen_string_literal: true

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
    include Util::Memoize
    include Enumerable
    include PathedNode
    class CannotSubscriptError < StandardError
    end

    class << self
      # JSI::Base.new_jsi behaves the same as .new, and is defined for compatibility so you may call #new_jsi
      # on any of a JSI::Schema, a JSI::SchemaModule, or a JSI schema class.
      # @return [JSI::Base] a JSI whose instance is the given instance
      def new_jsi(instance, *a, &b)
        new(instance, *a, &b)
      end

      # is the constant JSI::SchemaClasses::{self.schema_classes_const_name} defined?
      # (if so, we will prefer to use something more human-readable than that ugly mess.)
      def in_schema_classes
        # #name sets @in_schema_classes
        name
        @in_schema_classes
      end

      # @return [String] absolute schema_id of the schema this class represents.
      #   see {Schema#schema_id}.
      def schema_id
        schema.schema_id
      end

      # @return [String] a string representing the class, with schema_id or schema ptr fragment
      def inspect
        if !respond_to?(:schema)
          super
        else
          uri = schema_id || schema.node_ptr.uri
          if name && !in_schema_classes
            "#{name} (#{uri})"
          else
            "(JSI Schema Class: #{uri})"
          end
        end
      end

      alias_method :to_s, :inspect

      # @return [String] a name for a constant for this class, generated from the
      #   schema_id. only used if the class is not assigned to another constant.
      def schema_classes_const_name
        if schema_id
          'X' + schema_id.gsub(/[^\w]/, '_')
        end
      end

      # @return [String] a constant name of this class
      def name
        unless instance_variable_defined?(:@in_schema_classes)
          if super || !schema_id || SchemaClasses.const_defined?(schema_classes_const_name)
            @in_schema_classes = false
          else
            SchemaClasses.const_set(schema_classes_const_name, self)
            @in_schema_classes = true
          end
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
    # @param jsi_root_node [JSI::Base] for internal use, specifies the JSI at the root of the document
    def initialize(instance, jsi_document: nil, jsi_ptr: nil, jsi_root_node: nil)
      unless respond_to?(:schema)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #schema. please use JSI.class_for_schema")
      end

      if instance.is_a?(JSI::Schema)
        raise(TypeError, "assigning a schema to a #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      elsif instance.is_a?(JSI::Base)
        raise(TypeError, "assigning another JSI::Base instance to a #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      end

      if instance == NOINSTANCE
        @jsi_document = jsi_document
        unless jsi_ptr.is_a?(JSI::JSON::Pointer)
          raise(TypeError, "jsi_ptr must be a JSI::JSON::Pointer; got: #{jsi_ptr.inspect}")
        end
        @jsi_ptr = jsi_ptr
        if @jsi_ptr.root?
          raise(Bug, "jsi_root_node cannot be specified for root JSI") if jsi_root_node
          @jsi_root_node = self
        else
          if !jsi_root_node.is_a?(JSI::Base)
            raise(TypeError, "jsi_root_node must be a JSI::Base; got: #{jsi_root_node.inspect}")
          end
          if !jsi_root_node.jsi_ptr.root?
            raise(Bug, "jsi_root_node ptr #{jsi_root_node.jsi_ptr.inspect} is not root")
          end
          @jsi_root_node = jsi_root_node
        end
      else
        raise(Bug, 'incorrect usage') if jsi_document || jsi_ptr || jsi_root_node
        @jsi_document = instance
        @jsi_ptr = JSI::JSON::Pointer[]
        @jsi_root_node = self
      end

      if self.jsi_instance.respond_to?(:to_hash)
        extend PathedHashNode
      elsif self.jsi_instance.respond_to?(:to_ary)
        extend PathedArrayNode
      end
      if self.schema.describes_schema?
        extend JSI::Schema
      end
    end

    # document containing the instance of this JSI
    attr_reader :jsi_document

    # JSI::JSON::Pointer pointing to this JSI's instance within the jsi_document
    attr_reader :jsi_ptr

    # the JSI at the root of this JSI's document
    attr_reader :jsi_root_node

    alias_method :node_document, :jsi_document
    alias_method :node_ptr, :jsi_ptr
    alias_method :document_root_node, :jsi_root_node

    # the instance of the json-schema - the underlying JSON data used to instantiate this JSI
    alias_method :jsi_instance, :node_content
    alias_method :instance, :node_content

    # each is overridden by PathedHashNode or PathedArrayNode when appropriate. the base
    # #each is not actually implemented, along with all the methods of Enumerable.
    def each
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{jsi_instance.pretty_inspect.chomp}"
    end

    # an array of JSI instances above this one in the document.
    #
    # @return [Array<JSI::Base>]
    def parent_jsis
      parent = jsi_root_node

      jsi_ptr.reference_tokens.map do |token|
        parent.tap do
          parent = parent[token]
        end
      end.reverse
    end

    # the immediate parent of this JSI. nil if there is no parent.
    #
    # @return [JSI::Base, nil]
    def parent_jsi
      parent_jsis.first
    end

    alias_method :parent_node, :parent_jsi

    # @deprecated
    alias_method :parents, :parent_jsis
    # @deprecated
    alias_method :parent, :parent_jsi

    # @param token [String, Integer, Object] the token to subscript
    # @return [JSI::Base, Object] the instance's subscript value at the given token.
    #   if there is a subschema defined for that token on this JSI's schema,
    #   returns that value as a JSI instantiation of that subschema.
    def [](token)
      if respond_to?(:to_hash)
        token_in_range = node_content_hash_pubsend(:key?, token)
        value = node_content_hash_pubsend(:[], token)
      elsif respond_to?(:to_ary)
        token_in_range = node_content_ary_pubsend(:each_index).include?(token)
        value = node_content_ary_pubsend(:[], token)
      else
        raise(CannotSubscriptError, "cannot subcript (using token: #{token.inspect}) from instance: #{jsi_instance.pretty_inspect.chomp}")
      end

      result = jsi_memoize(:[], token, value, token_in_range) do |token, value, token_in_range|
        if respond_to?(:to_ary)
          token_schema = schema.subschema_for_index(token)
        else
          token_schema = schema.subschema_for_property(token)
        end
        token_schema = token_schema && token_schema.match_to_instance(value)

        if token_in_range
          complex_value = token_schema && (value.respond_to?(:to_hash) || value.respond_to?(:to_ary))
          schema_value = token_schema && token_schema.describes_schema?

          if complex_value || schema_value
            class_for_schema(token_schema).new(Base::NOINSTANCE, jsi_document: @jsi_document, jsi_ptr: @jsi_ptr[token], jsi_root_node: @jsi_root_node)
          else
            value
          end
        else
          defaults = Set.new
          if token_schema
            if token_schema.respond_to?(:to_hash) && token_schema.key?('default')
              defaults << token_schema['default']
            end
          end

          if defaults.size == 1
            # use the default value
            # we are using #dup so that we get a modified copy of self, in which we set dup[token]=default.
            dup.tap { |o| o[token] = defaults.first }[token]
          else
            # I kind of want to just return nil here. the preferred mechanism for
            # a JSI's default value should be its schema. but returning nil ignores
            # any value returned by Hash#default/#default_proc. there's no compelling
            # reason not to support both, so I'll return that.
            value
          end
        end
      end
      result
    end

    # assigns the subscript of the instance identified by the given token to the given value.
    # if the value is a JSI, its instance is assigned instead of the JSI value itself.
    #
    # @param token [String, Integer, Object] token identifying the subscript to assign
    # @param value [JSI::Base, Object] the value to be assigned
    def []=(token, value)
      unless respond_to?(:to_hash) || respond_to?(:to_ary)
        raise(NoMethodError, "cannot assign subcript (using token: #{token.inspect}) to instance: #{jsi_instance.pretty_inspect.chomp}")
      end
      jsi_clear_memo(:[])
      if value.is_a?(Base)
        self[token] = value.jsi_instance
      else
        jsi_instance[token] = value
      end
    end

    # if this JSI is a $ref then the $ref is followed. otherwise this JSI
    # is returned.
    #
    # @yield [JSI::Base] if a block is given (optional), this will yield a deref'd JSI. if this
    #   JSI is not a $ref object, the block is not called. if we are a $ref which cannot be followed
    #   (e.g. a $ref to an external document, which is not yet supported), the block is not called.
    # @return [JSI::Base, self]
    def deref(&block)
      node_ptr_deref do |deref_ptr|
        deref_ptr.evaluate(jsi_root_node).tap(&(block || Util::NOOP))
      end
      return self
    end

    # yields the content of the underlying instance. the block must result in
    # a modified copy of that (not destructively modifying the yielded content)
    # which will be used to instantiate a new instance of this JSI class with
    # the modified content.
    # @yield [Object] the content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [JSI::Base subclass the same as self] the modified copy of self
    def modified_copy(&block)
      if node_ptr.root?
        modified_document = @jsi_ptr.modified_document_copy(@jsi_document, &block)
        self.class.new(Base::NOINSTANCE, jsi_document: modified_document, jsi_ptr: @jsi_ptr)
      else
        modified_jsi_root_node = @jsi_root_node.modified_copy do |root|
          @jsi_ptr.modified_document_copy(root, &block)
        end
        self.class.new(Base::NOINSTANCE, jsi_document: modified_jsi_root_node.node_document, jsi_ptr: @jsi_ptr, jsi_root_node: modified_jsi_root_node)
      end
    end

    # @return [Array] array of schema validation errors for this instance
    def fully_validate(errors_as_objects: false)
      schema.fully_validate_instance(jsi_instance, errors_as_objects: errors_as_objects)
    end

    # @return [true, false] whether the instance validates against its schema
    def validate
      schema.validate_instance(jsi_instance)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate a valid instance.
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors
    def validate!
      schema.validate_instance!(jsi_instance)
    end

    def dup
      modified_copy(&:dup)
    end

    # @return [String] a string representing this JSI, indicating its class
    #   and inspecting its instance
    def inspect
      "\#<#{object_group_text.join(' ')} #{jsi_instance.inspect}>"
    end

    # pretty-prints a representation this JSI to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text object_group_text.join(' ')
      q.group_sub {
        q.nest(2) {
          q.breakable ' '
          q.pp jsi_instance
        }
      }
      q.breakable ''
      q.text '>'
    end

    # @return [Array<String>]
    def object_group_text
      class_name = self.class.name unless self.class.in_schema_classes
      class_txt = begin
        if class_name
          # ignore ID
          schema_name = schema.jsi_schema_module.name
          if !schema_name
            class_name
          else
            "#{class_name} (#{schema_name})"
          end
        else
          schema_name = schema.jsi_schema_module.name || schema.schema_id
          if !schema_name
            "JSI"
          else
            "JSI (#{schema_name})"
          end
        end
      end

      if (is_a?(PathedArrayNode) || is_a?(PathedHashNode)) && ![Array, Hash].include?(node_content.class)
        if node_content.respond_to?(:object_group_text)
          node_content_txt = node_content.object_group_text
        else
          node_content_txt = [node_content.class.to_s]
        end
      else
        node_content_txt = []
      end

      [
        class_txt,
        is_a?(Metaschema) ? "Metaschema" : is_a?(Schema) ? "Schema" : nil,
        *node_content_txt,
      ].compact
    end

    # @return [Object] a jsonifiable representation of the instance
    def as_json(*opt)
      Typelike.as_json(jsi_instance, *opt)
    end

    # @return [Object] an opaque fingerprint of this JSI for FingerprintHash. JSIs are equal
    #   if their instances are equal, and if the JSIs are of the same JSI class or subclass.
    def jsi_fingerprint
      {class: jsi_class, jsi_document: jsi_document, jsi_ptr: jsi_ptr}
    end
    include Util::FingerprintHash

    private

    # this is an instance method in order to allow subclasses of JSI classes to
    # override it to point to other subclasses corresponding to other schemas.
    def class_for_schema(schema)
      JSI.class_for_schema(schema)
    end
  end
end
