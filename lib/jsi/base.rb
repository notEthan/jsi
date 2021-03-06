# frozen_string_literal: true

module JSI
  # JSI::Base is the class from which JSI schema classes inherit. a JSON schema instance is represented as a
  # ruby instance of such a subclass of JSI::Base.
  #
  # instances are described by a set of one or more JSON schemas. JSI dynamically creates a subclass of
  # JSI::Base for each set of JSON schemas which describe a schema instance that is to be instantiated.
  # a JSI instance of such a subclass represents a JSON schema instance described by that set of schemas.
  #
  # the JSI::Base class itself is not intended to be instantiated.
  class Base
    include PathedNode
    include Schema::SchemaAncestorNode
    include Util::Memoize

    # not every JSI::Base is necessarily an Enumerable, but it's better to include Enumerable on
    # the class than to conditionally extend the instance.
    include Enumerable

    # an exception raised when #[] is invoked on an instance which is not an array or hash
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

      # @return [String] a string indicating a class name if one is defined, as well as the schema module name
      #   and/or schema URI of each schema the class represents.
      def inspect
        if !respond_to?(:jsi_class_schemas)
          super
        else
          schema_names = jsi_class_schemas.map do |schema|
            mod = schema.jsi_schema_module
            if mod.name && schema.schema_id
              "#{mod.name} (#{schema.schema_id})"
            elsif mod.name
              mod.name
            elsif schema.schema_id
              schema.schema_id
            else
              schema.jsi_ptr.uri
            end
          end

          if name && !in_schema_classes
            if jsi_class_schemas.empty?
              "#{name} (0 schemas)"
            else
              "#{name} (#{schema_names.join(', ')})"
            end
          else
            if schema_names.empty?
              "(JSI Schema Class for 0 schemas)"
            else
              "(JSI Schema Class: #{schema_names.join(', ')})"
            end
          end
        end
      end

      alias_method :to_s, :inspect

      # @return [String, nil] a name for a constant for this class, generated from the constant name
      #   or schema id of each schema this class represents. nil if any represented schema has no constant
      #   name or schema id.
      def schema_classes_const_name
        if respond_to?(:jsi_class_schemas)
          schema_names = jsi_class_schemas.map do |schema|
            if schema.jsi_schema_module.name
              schema.jsi_schema_module.name
            elsif schema.schema_id
              schema.schema_id
            else
              nil
            end
          end
          if !schema_names.any?(&:nil?) && !schema_names.empty?
            schema_names.sort.map { |n| 'X' + n.gsub(/[^\w]/, '_') }.join('')
          end
        end
      end

      # @return [String] a constant name of this class
      def name
        unless instance_variable_defined?(:@in_schema_classes)
          const_name = schema_classes_const_name
          if super || !const_name || SchemaClasses.const_defined?(const_name)
            @in_schema_classes = false
          else
            SchemaClasses.const_set(const_name, self)
            @in_schema_classes = true
          end
        end
        super
      end
    end

    # NOINSTANCE is a magic value passed to #initialize when instantiating a JSI
    # from a document and JSON Pointer.
    #
    # @private
    NOINSTANCE = Object.new
    [:inspect, :to_s].each(&(-> (s, m) { NOINSTANCE.define_singleton_method(m) { s } }.curry.("#{JSI::Base}::NOINSTANCE")))
    NOINSTANCE.freeze

    # initializes this JSI from the given instance - instance is most commonly
    # a parsed JSON document consisting of Hash, Array, or sometimes a basic
    # type, but this is in no way enforced and a JSI may wrap any object.
    #
    # @param instance [Object] the JSON Schema instance to be represented as a JSI
    # @param jsi_document [Object] for internal use. the instance may be specified as a
    #   node in the `jsi_document` param, pointed to by `jsi_ptr`. the param `instance`
    #   MUST be `NOINSTANCE` to use the jsi_document + jsi_ptr form. `jsi_document` MUST
    #   NOT be passed if `instance` is anything other than `NOINSTANCE`.
    # @param jsi_ptr [JSI::JSON::Pointer] for internal use. a JSON pointer specifying
    #   the path of this instance in the `jsi_document` param. `jsi_ptr` must be passed
    #   iff `jsi_document` is passed, i.e. when `instance` is `NOINSTANCE`
    # @param jsi_root_node [JSI::Base] for internal use, specifies the JSI at the root of the document
    def initialize(instance,
        jsi_document: nil,
        jsi_ptr: nil,
        jsi_root_node: nil,
        jsi_schema_base_uri: nil,
        jsi_schema_resource_ancestors: []
    )
      unless respond_to?(:jsi_schemas)
        raise(TypeError, "cannot instantiate #{self.class.inspect} which has no method #jsi_schemas. it is recommended to instantiate JSIs from a schema using JSI::Schema#new_jsi.")
      end

      if instance.is_a?(JSI::Schema)
        raise(TypeError, "assigning a schema to a #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      elsif instance.is_a?(JSI::Base)
        raise(TypeError, "assigning another JSI::Base instance to a #{self.class.inspect} instance is incorrect. received: #{instance.pretty_inspect.chomp}")
      end

      jsi_initialize_memos

      if instance == NOINSTANCE
        self.jsi_document = jsi_document
        self.jsi_ptr = jsi_ptr
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

      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors

      if self.jsi_instance.respond_to?(:to_hash)
        extend PathedHashNode
      end
      if self.jsi_instance.respond_to?(:to_ary)
        extend PathedArrayNode
      end
    end

    # document containing the instance of this JSI
    attr_reader :jsi_document

    # JSI::JSON::Pointer pointing to this JSI's instance within the jsi_document
    attr_reader :jsi_ptr

    # the JSI at the root of this JSI's document
    attr_reader :jsi_root_node

    # the instance of the json-schema - the underlying JSON data used to instantiate this JSI
    alias_method :jsi_instance, :jsi_node_content

    # each is overridden by PathedHashNode or PathedArrayNode when appropriate. the base #each
    # is not actually implemented, along with all the methods of Enumerable.
    def each
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{jsi_instance.pretty_inspect.chomp}"
    end

    # an array of JSI instances above this one in the document.
    #
    # @return [Array<JSI::Base>]
    def jsi_parent_nodes
      parent = jsi_root_node

      jsi_ptr.reference_tokens.map do |token|
        parent.tap do
          parent = parent[token, as_jsi: true]
        end
      end.reverse
    end

    # the immediate parent of this JSI. nil if there is no parent.
    #
    # @return [JSI::Base, nil]
    def jsi_parent_node
      jsi_parent_nodes.first
    end

    # @param token [String, Integer, Object] the token to subscript
    # @param as_jsi [:auto, true, false] whether to return the result value as a JSI. one of:
    #   - :auto (default): by default a JSI will be returned when either:
    #     - the result is a complex value (responds to #to_ary or #to_hash) and is described by some schemas
    #     - the result is a schema (including true/false schemas)
    #     a plain value is returned when no schemas are known to describe the instance, or when the value is a
    #     simple type (anything unresponsive to #to_ary / #to_hash).
    #   - true: the result value will always be returned as a JSI. the #jsi_schemas of the result may be empty
    #     if no schemas describe the instance.
    #   - false: the result value will always be the plain instance.
    #
    #   note that nil is returned (regardless of as_jsi) when there is no value to return because the token
    #   is not a hash key or array index of the instance and no default value applies.
    #   (one exception is when this JSI's instance is a Hash with a default or default_proc, which has
    #   unspecified behavior.)
    # @return [JSI::Base, Object] the instance's subscript value at the given token.
    def [](token, as_jsi: :auto)
      if respond_to?(:to_hash)
        token_in_range = jsi_node_content_hash_pubsend(:key?, token)
        value = jsi_node_content_hash_pubsend(:[], token)
      elsif respond_to?(:to_ary)
        token_in_range = jsi_node_content_ary_pubsend(:each_index).include?(token)
        value = jsi_node_content_ary_pubsend(:[], token)
      else
        raise(CannotSubscriptError, "cannot subcript (using token: #{token.inspect}) from instance: #{jsi_instance.pretty_inspect.chomp}")
      end

      begin
        subinstance_schemas = jsi_subinstance_schemas_memos[token: token, value: value]

        if token_in_range
          jsi_subinstance_as_jsi(value, subinstance_schemas, as_jsi) do
            jsi_subinstance_memos[token: token, subinstance_schemas: subinstance_schemas]
          end
        else
          defaults = Set.new
          subinstance_schemas.each do |subinstance_schema|
            if subinstance_schema.respond_to?(:to_hash) && subinstance_schema.key?('default')
              defaults << subinstance_schema['default']
            end
          end

          if defaults.size == 1
            # use the default value
            # we are using #dup so that we get a modified copy of self, in which we set dup[token]=default.
            dup.tap { |o| o[token] = defaults.first }[token, as_jsi: as_jsi]
          else
            # I kind of want to just return nil here. the preferred mechanism for
            # a JSI's default value should be its schema. but returning nil ignores
            # any value returned by Hash#default/#default_proc. there's no compelling
            # reason not to support both, so I'll return that.
            value
          end
        end
      end
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
      if value.is_a?(Base)
        self[token] = value.jsi_instance
      else
        jsi_instance[token] = value
      end
    end

    # @return [Set<Module>] the set of JSI schema modules corresponding to the schemas that describe this JSI
    def jsi_schema_modules
      jsi_schemas.map(&:jsi_schema_module).to_set.freeze
    end

    # yields the content of the underlying instance. the block must result in
    # a modified copy of that (not destructively modifying the yielded content)
    # which will be used to instantiate a new instance of this JSI class with
    # the modified content.
    # @yield [Object] the content of the instance. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [JSI::Base subclass the same as self] the modified copy of self
    def jsi_modified_copy(&block)
      if @jsi_ptr.root?
        modified_document = @jsi_ptr.modified_document_copy(@jsi_document, &block)
        self.class.new(Base::NOINSTANCE,
          jsi_document: modified_document,
          jsi_ptr: @jsi_ptr,
          jsi_schema_base_uri: @jsi_schema_base_uri,
          jsi_schema_resource_ancestors: @jsi_schema_resource_ancestors, # this can only be empty but included for consistency
        )
      else
        modified_jsi_root_node = @jsi_root_node.jsi_modified_copy do |root|
          @jsi_ptr.modified_document_copy(root, &block)
        end
        @jsi_ptr.evaluate(modified_jsi_root_node)
      end
    end

    # @return [Array] array of schema validation errors for this instance
    def fully_validate(errors_as_objects: false)
      jsi_schemas.map { |schema| schema.fully_validate_instance(jsi_instance, errors_as_objects: errors_as_objects) }.inject([], &:+)
    end

    # @return [true, false] whether the instance validates against its schema
    def validate
      jsi_schemas.all? { |schema| schema.validate_instance(jsi_instance) }
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate a valid instance.
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors
    def validate!
      jsi_schemas.each { |schema| schema.validate_instance!(jsi_instance) }
      true
    end

    def dup
      jsi_modified_copy(&:dup)
    end

    # @return [String] a string representing this JSI, indicating its class
    #   and inspecting its instance
    def inspect
      "\#<#{jsi_object_group_text.join(' ')} #{jsi_instance.inspect}>"
    end

    # pretty-prints a representation of this JSI to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text jsi_object_group_text.join(' ')
      q.group_sub {
        q.nest(2) {
          q.breakable ' '
          q.pp jsi_instance
        }
      }
      q.breakable ''
      q.text '>'
    end

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      class_name = self.class.name unless self.class.in_schema_classes
      class_txt = begin
        if class_name
          # ignore ID
          schema_module_names = jsi_schemas.map { |schema| schema.jsi_schema_module.name }.compact
          if schema_module_names.empty?
            class_name
          else
            "#{class_name} (#{schema_module_names.join(', ')})"
          end
        else
          schema_names = jsi_schemas.map { |schema| schema.jsi_schema_module.name || schema.schema_id }.compact
          if schema_names.empty?
            "JSI"
          else
            "JSI (#{schema_names.join(', ')})"
          end
        end
      end

      if (is_a?(PathedArrayNode) || is_a?(PathedHashNode)) && ![Array, Hash].include?(jsi_node_content.class)
        if jsi_node_content.respond_to?(:jsi_object_group_text)
          content_txt = jsi_node_content.jsi_object_group_text
        else
          content_txt = [jsi_node_content.class.to_s]
        end
      else
        content_txt = []
      end

      [
        class_txt,
        is_a?(Metaschema) ? "Metaschema" : is_a?(Schema) ? "Schema" : nil,
        *content_txt,
      ].compact
    end

    # @return [Object] a jsonifiable representation of the instance
    def as_json(*opt)
      Typelike.as_json(jsi_instance, *opt)
    end

    # @return [Object] an opaque fingerprint of this JSI for FingerprintHash. JSIs are equal
    #   if their instances are equal, and if the JSIs are of the same JSI class or subclass.
    def jsi_fingerprint
      {
        class: jsi_class,
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        # for instances in documents with schemas:
        jsi_schema_base_uri: is_a?(Schema) ? jsi_subschema_base_uri : jsi_schema_base_uri,
        # only defined for JSI::Schema instances:
        jsi_schema_instance_modules: is_a?(Schema) ? jsi_schema_instance_modules : nil,
      }
    end
    include Util::FingerprintHash

    private

    def jsi_subinstance_schemas_memos
      jsi_memomap(:subinstance_schemas, key_by: -> (i) { i[:token] }) do |token: , value: |
        jsi_schemas.map do |schema|
          if respond_to?(:to_ary)
            subschemas = schema.subschemas_for_index(token)
          elsif respond_to?(:to_hash)
            subschemas = schema.subschemas_for_property_name(token)
          else
            raise(Bug, 'jsi_subinstance_schemas_memos: not array or hash')
          end
          subschemas.map { |subschema| subschema.match_to_instance(value) }.inject(Set.new, &:|)
        end.inject(Set.new, &:|).freeze
      end
    end

    def jsi_subinstance_memos
      jsi_memomap(:subinstance, key_by: -> (i) { i[:token] }) do |token: , subinstance_schemas: |
        JSI::SchemaClasses.class_for_schemas(subinstance_schemas).new(Base::NOINSTANCE,
          jsi_document: @jsi_document,
          jsi_ptr: @jsi_ptr[token],
          jsi_root_node: @jsi_root_node,
          jsi_schema_base_uri: is_a?(Schema) ? jsi_subschema_base_uri : jsi_schema_base_uri,
          jsi_schema_resource_ancestors: is_a?(Schema) ? jsi_subschema_resource_ancestors : jsi_schema_resource_ancestors,
        )
      end
    end

    def jsi_subinstance_as_jsi(value, subinstance_schemas, as_jsi)
      value_as_jsi = if [true, false].include?(as_jsi)
        as_jsi
      elsif as_jsi == :auto
        complex_value = subinstance_schemas.any? && (value.respond_to?(:to_hash) || value.respond_to?(:to_ary))
        schema_value = subinstance_schemas.any? { |subinstance_schema| subinstance_schema.describes_schema? }
        complex_value || schema_value
      else
        raise(ArgumentError, "as_jsi must be one of: :auto, true, false")
      end

      if value_as_jsi
        yield
      else
        value
      end
    end
  end
end
