# frozen_string_literal: true

module JSI
  # JSI::Base is the base class of every JSI instance of a JSON schema.
  #
  # instances are described by a set of one or more JSON schemas. JSI dynamically creates a subclass of
  # JSI::Base for each set of JSON schemas which describe an instance that is to be instantiated.
  #
  # a JSI instance of such a subclass represents a JSON schema instance described by that set of schemas.
  #
  # this subclass includes the JSI Schema Module of each schema it represents.
  #
  # the method {Base#jsi_schemas} is defined to indicate the schemas the class represents.
  #
  # the JSI::Base class itself is not intended to be instantiated.
  class Base
    autoload :ArrayNode, 'jsi/base/node'
    autoload :HashNode, 'jsi/base/node'

    include Schema::SchemaAncestorNode
    include Util::Memoize

    # not every JSI::Base is necessarily an Enumerable, but it's better to include Enumerable on
    # the class than to conditionally extend the instance.
    include Enumerable

    # an exception raised when {Base#[]} is invoked on an instance which is not an array or hash
    class CannotSubscriptError < StandardError
    end

    class << self
      # @private
      # is the constant JSI::SchemaClasses::<self.schema_classes_const_name> defined?
      # (if so, we will prefer to use something more human-readable than that ugly mess.)
      def in_schema_classes
        # #name sets @in_schema_classes
        name
        @in_schema_classes
      end

      # a string indicating a class name if one is defined, as well as the schema module name
      # and/or schema URI of each schema the class represents.
      # @return [String]
      def inspect
        if !respond_to?(:jsi_class_schemas)
          super
        else
          schema_names = jsi_class_schemas.map do |schema|
            mod = schema.jsi_schema_module
            if mod.name && schema.schema_uri
              "#{mod.name} (#{schema.schema_uri})"
            elsif mod.name
              mod.name
            elsif schema.schema_uri
              schema.schema_uri.to_s
            else
              schema.jsi_ptr.uri.to_s
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

      # @private
      # see {.name}
      def schema_classes_const_name
        if respond_to?(:jsi_class_schemas)
          schema_names = jsi_class_schemas.map do |schema|
            named_ancestor_schema, tokens = schema.jsi_schema_module.send(:named_ancestor_schema_tokens)
            if named_ancestor_schema
              [named_ancestor_schema.jsi_schema_module.name, *tokens].join('_')
            elsif schema.schema_uri
              schema.schema_uri.to_s
            else
              nil
            end
          end
          if !schema_names.any?(&:nil?) && !schema_names.empty?
            schema_names.sort.map { |n| 'X' + n.to_s.gsub(/[^\w]/, '_') }.join('')
          end
        end
      end

      # a constant name of this class. this is generated from the schema module name or URI of each schema
      # this class represents. nil if any represented schema has no schema module name or schema URI.
      #
      # this generated name is not too pretty but can be more helpful than an anonymous class, especially
      # in error messages.
      #
      # @return [String]
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

    # initializes a JSI whose instance is in the given document at the given pointer.
    #
    # this is a private api - users should look elsewhere to instantiate JSIs, in particular:
    #
    # - {JSI.new_schema} and {Schema::DescribesSchema#new_schema} to instantiate schemas
    # - {Schema#new_jsi} to instantiate schema instances
    #
    # @api private
    # @param jsi_document [Object] the document containing the instance
    # @param jsi_ptr [JSI::Ptr] a pointer pointing to the JSI's instance in the document
    # @param jsi_root_node [JSI::Base] the JSI of the root of the document containing this JSI
    # @param jsi_schema_base_uri [Addressable::URI] see {SchemaSet#new_jsi} param uri
    # @param jsi_schema_resource_ancestors [Array<JSI::Base<JSI::Schema>>]
    def initialize(jsi_document,
        jsi_ptr: Ptr[],
        jsi_root_node: nil,
        jsi_schema_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY
    )
      raise(Bug, "no #jsi_schemas") unless respond_to?(:jsi_schemas)

      jsi_initialize_memos

      self.jsi_document = jsi_document
      self.jsi_ptr = jsi_ptr
      if @jsi_ptr.root?
        raise(Bug, "jsi_root_node specified for root JSI") if jsi_root_node
        @jsi_root_node = self
      else
        raise(Bug, "jsi_root_node is not JSI::Base") if !jsi_root_node.is_a?(JSI::Base)
        raise(Bug, "jsi_root_node ptr is not root") if !jsi_root_node.jsi_ptr.root?
        @jsi_root_node = jsi_root_node
      end
      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors

      if jsi_instance.respond_to?(:to_hash)
        extend HashNode
      end
      if jsi_instance.respond_to?(:to_ary)
        extend ArrayNode
      end

      if jsi_instance.is_a?(JSI::Base)
        raise(TypeError, "a JSI::Base instance must not be another JSI::Base. received: #{jsi_instance.pretty_inspect.chomp}")
      end
    end

    # @!method jsi_schemas
    #   the set of schemas which describe this instance
    #   @return [JSI::SchemaSet]
    # note: defined on subclasses by JSI::SchemaClasses.class_for_schemas


    # document containing the instance of this JSI at our {#jsi_ptr}
    attr_reader :jsi_document

    # {JSI::Ptr} pointing to this JSI's instance within our {#jsi_document}
    # @return [JSI::Ptr]
    attr_reader :jsi_ptr

    # the JSI at the root of this JSI's document
    # @return [JSI::Base]
    attr_reader :jsi_root_node

    # the content of this node in our {#jsi_document} at our {#jsi_ptr}. the same as {#jsi_instance}.
    def jsi_node_content
      content = jsi_ptr.evaluate(jsi_document)
      content
    end

    # the JSON schema instance this JSI represents - the underlying JSON data used to instantiate this JSI
    alias_method :jsi_instance, :jsi_node_content

    # each is overridden by Base::HashNode or Base::ArrayNode when appropriate. the base #each
    # is not actually implemented, along with all the methods of Enumerable.
    def each(*_)
      raise NoMethodError, "Enumerable methods and #each not implemented for instance that is not like a hash or array: #{jsi_instance.pretty_inspect.chomp}"
    end

    # yields a JSI of each node at or below this one in this JSI's document.
    #
    # returns an Enumerator if no block is given.
    #
    # @yield [JSI::Base] each descendent node, starting with self
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_descendent_node(&block)
      return to_enum(__method__) unless block

      yield self
      if respond_to?(:to_hash)
        each_key do |k|
          self[k, as_jsi: true].jsi_each_descendent_node(&block)
        end
      elsif respond_to?(:to_ary)
        each_index do |i|
          self[i, as_jsi: true].jsi_each_descendent_node(&block)
        end
      end
      nil
    end

    # recursively selects descendent nodes of this JSI, returning a modified copy of self containing only
    # descendent nodes for which the given block had a true-ish result.
    #
    # this method yields a node before recursively descending to its child nodes, so leaf nodes are yielded
    # last, after their parents. if a node is not selected, its descendents are never recursed.
    #
    # @yield [JSI::Base] each descendent node below self
    # @return [JSI::Base] modified copy of self containing only the selected nodes
    def jsi_select_descendents_node_first(&block)
      jsi_modified_copy do |instance|
        if respond_to?(:to_hash)
          res = instance.class.new
          each_key do |k|
            v = self[k, as_jsi: true]
            if yield(v)
              res[k] = v.jsi_select_descendents_node_first(&block).jsi_node_content
            end
          end
          res
        elsif respond_to?(:to_ary)
          res = instance.class.new
          each_index do |i|
            e = self[i, as_jsi: true]
            if yield(e)
              res << e.jsi_select_descendents_node_first(&block).jsi_node_content
            end
          end
          res
        else
          instance
        end
      end
    end

    # @deprecated after v0.6
    alias_method :jsi_select_children_node_first, :jsi_select_descendents_node_first

    # recursively selects descendent nodes of this JSI, returning a modified copy of self containing only
    # descendent nodes for which the given block had a true-ish result.
    #
    # this method recursively descends child nodes before yielding each node, so leaf nodes are yielded
    # before their parents.
    #
    # @yield [JSI::Base] each descendent node below self
    # @return [JSI::Base] modified copy of self containing only the selected nodes
    def jsi_select_descendents_leaf_first(&block)
      jsi_modified_copy do |instance|
        if respond_to?(:to_hash)
          res = instance.class.new
          each_key do |k|
            v = self[k, as_jsi: true].jsi_select_descendents_leaf_first(&block)
            if yield(v)
              res[k] = v.jsi_node_content
            end
          end
          res
        elsif respond_to?(:to_ary)
          res = instance.class.new
          each_index do |i|
            e = self[i, as_jsi: true].jsi_select_descendents_leaf_first(&block)
            if yield(e)
              res << e.jsi_node_content
            end
          end
          res
        else
          instance
        end
      end
    end

    # @deprecated after v0.6
    alias_method :jsi_select_children_leaf_first, :jsi_select_descendents_leaf_first

    # an array of JSI instances above this one in the document.
    #
    # @return [Array<JSI::Base>]
    def jsi_parent_nodes
      parent = jsi_root_node

      jsi_ptr.tokens.map do |token|
        parent.tap do
          parent = parent[token, as_jsi: true]
        end
      end.reverse
    end

    # the immediate parent of this JSI. nil if there is no parent.
    #
    # @return [JSI::Base, nil]
    def jsi_parent_node
      jsi_ptr.root? ? nil : jsi_root_node.jsi_descendent_node(jsi_ptr.parent)
    end

    # the descendent node at the given pointer
    #
    # @param ptr [JSI::Ptr, #to_ary]
    # @return [JSI::Base]
    def jsi_descendent_node(ptr)
      descendent = Ptr.ary_ptr(ptr).evaluate(self, as_jsi: true)
      descendent
    end

    # subscripts to return a child value identified by the given token.
    #
    # @param token [String, Integer, Object] an array index or hash key (JSON object property name)
    #   of the instance identifying the child value
    # @param as_jsi [:auto, true, false] whether to return the result value as a JSI. one of:
    #
    #   - :auto (default): by default a JSI will be returned when either:
    #
    #     - the result is a complex value (responds to #to_ary or #to_hash)
    #     - the result is a schema (including true/false schemas)
    #
    #     a plain value is returned when no schemas are known to describe the instance, or when the value is a
    #     simple type (anything unresponsive to #to_ary / #to_hash).
    #
    #   - true: the result value will always be returned as a JSI. the {#jsi_schemas} of the result may be
    #     empty if no schemas describe the instance.
    #   - false: the result value will always be the plain instance.
    #
    #   note that nil is returned (regardless of as_jsi) when there is no value to return because the token
    #   is not a hash key or array index of the instance and no default value applies.
    #   (one exception is when this JSI's instance is a Hash with a default or default_proc, which has
    #   unspecified behavior.)
    # @param use_default [true, false] whether to return a schema default value when the token is not in
    #   range. if the token is not an array index or hash key of the instance, and one schema for the child
    #   instance specifies a default value, that default is returned.
    #
    #   if the result with the default value is a JSI (per the `as_jsi` param), that JSI is not a child of
    #   this JSI - this JSI is not modified to fill in the default value. the result is a JSI within a new
    #   document containing the filled-in default.
    #
    #   if the child instance's schemas do not indicate a single default value (that is, if zero or multiple
    #   defaults are specified across those schemas), nil is returned.
    #   (one exception is when this JSI's instance is a Hash with a default or default_proc, which has
    #   unspecified behavior.)
    # @return [JSI::Base, Object] the child value identified by the subscript token
    def [](token, as_jsi: :auto, use_default: true)
      if respond_to?(:to_hash)
        token_in_range = jsi_node_content_hash_pubsend(:key?, token)
        value = jsi_node_content_hash_pubsend(:[], token)
      elsif respond_to?(:to_ary)
        token_in_range = jsi_node_content_ary_pubsend(:each_index).include?(token)
        value = jsi_node_content_ary_pubsend(:[], token)
      else
        raise(CannotSubscriptError, "cannot subscript (using token: #{token.inspect}) from instance: #{jsi_instance.pretty_inspect.chomp}")
      end

      begin
        subinstance_schemas = jsi_subinstance_schemas_memos[token: token, instance: jsi_node_content, subinstance: value]

        if token_in_range
          jsi_subinstance_as_jsi(value, subinstance_schemas, as_jsi) do
            jsi_subinstance_memos[
              token: token,
              subinstance_schemas: subinstance_schemas,
            ]
          end
        else
          if use_default
            defaults = Set.new
            subinstance_schemas.each do |subinstance_schema|
              if subinstance_schema.keyword?('default')
                defaults << subinstance_schema.jsi_node_content['default']
              end
            end
          end

          if use_default && defaults.size == 1
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
        raise(CannotSubscriptError, "cannot assign subscript (using token: #{token.inspect}) to instance: #{jsi_instance.pretty_inspect.chomp}")
      end
      if value.is_a?(Base)
        self[token] = value.jsi_instance
      else
        jsi_instance[token] = value
      end
    end

    # the set of JSI schema modules corresponding to the schemas that describe this JSI
    # @return [Set<Module>]
    def jsi_schema_modules
      Util.ensure_module_set(jsi_schemas.map(&:jsi_schema_module))
    end

    # yields the content of this JSI's instance. the block must result in
    # a modified copy of the yielded instance (not modified in place, which would alter this JSI
    # as well) which will be used to instantiate and return a new JSI with the modified content.
    #
    # the result may have different schemas which describe it than this JSI's schemas,
    # if conditional applicator schemas apply differently to the modified instance.
    #
    # @yield [Object] this JSI's instance. the block should result
    #   in a nondestructively modified copy of this.
    # @return [JSI::Base subclass] the modified copy of self
    def jsi_modified_copy(&block)
      if @jsi_ptr.root?
        modified_document = @jsi_ptr.modified_document_copy(@jsi_document, &block)
        jsi_schemas.new_jsi(modified_document,
          uri: jsi_schema_base_uri,
        )
      else
        modified_jsi_root_node = @jsi_root_node.jsi_modified_copy do |root|
          @jsi_ptr.modified_document_copy(root, &block)
        end
        modified_jsi_root_node.jsi_descendent_node(@jsi_ptr)
      end
    end

    # validates this JSI's instance against its schemas
    #
    # @return [JSI::Validation::FullResult]
    def jsi_validate
      jsi_schemas.instance_validate(self)
    end

    # whether this JSI's instance is valid against all of its schemas
    # @return [Boolean]
    def jsi_valid?
      jsi_schemas.instance_valid?(self)
    end

    def dup
      jsi_modified_copy(&:dup)
    end

    # a string representing this JSI, indicating any named schemas and inspecting its instance
    # @return [String]
    def inspect
      "\#<#{jsi_object_group_text.join(' ')} #{jsi_instance.inspect}>"
    end

    alias_method :to_s, :inspect

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

    # an Array containing each item in this JSI, if this JSI's instance is enumerable. the same
    # as `Enumerable#to_a`.
    #
    # @param kw keyword arguments are passed to {#[]} - see its keyword params
    # @return [Array]
    def to_a(**kw)
      # TODO remove eventually (keyword argument compatibility)
      # discard when all supported ruby versions delegate keywords to #each (3.0.1 breaks; 2.7.x warns)
      # https://bugs.ruby-lang.org/issues/18289
      ary = []
      each(**kw) do |e|
        ary << e
      end
      ary
    end

    alias_method :entries, :to_a

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      schema_names = jsi_schemas.map { |schema| schema.jsi_schema_module.name_from_ancestor || schema.schema_uri }.compact
      if schema_names.empty?
        class_txt = "JSI"
      else
        class_txt = "JSI (#{schema_names.join(', ')})"
      end

      if (is_a?(ArrayNode) || is_a?(HashNode)) && ![Array, Hash].include?(jsi_node_content.class)
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

    # a jsonifiable representation of the instance
    # @return [Object]
    def as_json(*opt)
      Typelike.as_json(jsi_instance, *opt)
    end

    # an opaque fingerprint of this JSI for {Util::FingerprintHash}.
    def jsi_fingerprint
      {
        class: jsi_class,
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        # for instances in documents with schemas:
        jsi_resource_ancestor_uri: jsi_resource_ancestor_uri,
        # only defined for JSI::Schema instances:
        jsi_schema_instance_modules: is_a?(Schema) ? jsi_schema_instance_modules : nil,
      }
    end
    include Util::FingerprintHash

    private

    def jsi_subinstance_schemas_memos
      jsi_memomap(:subinstance_schemas, key_by: -> (i) { i[:token] }) do |token: , instance: , subinstance: |
        jsi_schemas.child_applicator_schemas(token, instance).inplace_applicator_schemas(subinstance)
      end
    end

    def jsi_subinstance_memos
      jsi_memomap(:subinstance, key_by: -> (i) { i[:token] }) do |token: , subinstance_schemas: |
        jsi_class = JSI::SchemaClasses.class_for_schemas(subinstance_schemas)
        jsi_class.new(@jsi_document,
          jsi_ptr: @jsi_ptr[token],
          jsi_root_node: @jsi_root_node,
          jsi_schema_base_uri: jsi_resource_ancestor_uri,
          jsi_schema_resource_ancestors: is_a?(Schema) ? jsi_subschema_resource_ancestors : jsi_schema_resource_ancestors,
        )
      end
    end

    def jsi_subinstance_as_jsi(value, subinstance_schemas, as_jsi)
      value_as_jsi = if [true, false].include?(as_jsi)
        as_jsi
      elsif as_jsi == :auto
        complex_value = value.respond_to?(:to_hash) || value.respond_to?(:to_ary)
        schema_value = subinstance_schemas.any?(&:describes_schema?)
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
