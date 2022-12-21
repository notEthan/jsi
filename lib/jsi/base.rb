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

    # An exception raised when attempting to access a child of a node which cannot have children.
    # A complex node can have children, a simple node cannot.
    class SimpleNodeChildError < StandardError
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
        jsi_indicated_schemas: ,
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
      self.jsi_indicated_schemas = jsi_indicated_schemas
      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors

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

    # the schemas indicated as describing this instance, prior to inplace application.
    #
    # this is different from {#jsi_schemas}, which are the inplace applicator schemas
    # which describe this instance. for most purposes, `#jsi_schemas` is more relevant.
    #
    # `jsi_indicated_schemas` does not include inplace applicator schemas, such as the
    # subschemas of `allOf`, whereas `#jsi_schemas` does.
    #
    # this does include indicated schemas which do not apply themselves, such as `$ref`
    # schemas (on json schema drafts up to 7) - these are not included on `#jsi_schemas`.
    #
    # @return [JSI::SchemaSet]
    attr_reader :jsi_indicated_schemas

    # yields a JSI of each node at or below this one in this JSI's document.
    #
    # returns an Enumerator if no block is given.
    #
    # @yield [JSI::Base] each descendent node, starting with self
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_descendent_node(&block)
      return to_enum(__method__) unless block

      yield self

      jsi_each_child_token do |token|
        self[token, as_jsi: true].jsi_each_descendent_node(&block)
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
        if jsi_array? || jsi_hash?
          res = instance.class.new
          jsi_each_child_token do |token|
            v = self[token, as_jsi: true]
            if yield(v)
              res_v = v.jsi_select_descendents_node_first(&block).jsi_node_content
              if jsi_array?
                res << res_v
              else
                res[token] = res_v
              end
            end
          end
          res
        else
          instance
        end
      end
    end

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
        if jsi_array? || jsi_hash?
          res = instance.class.new
          jsi_each_child_token do |token|
            v = self[token, as_jsi: true].jsi_select_descendents_leaf_first(&block)
            if yield(v)
              res_v = v.jsi_node_content
              if jsi_array?
                res << res_v
              else
                res[token] = res_v
              end
            end
          end
          res
        else
          instance
        end
      end
    end

    # an array of JSI instances above this one in the document.
    #
    # @return [Array<JSI::Base>]
    def jsi_parent_nodes
      parent = jsi_root_node

      jsi_ptr.tokens.map do |token|
        parent.tap do
          parent = parent[token, as_jsi: true]
        end
      end.reverse!.freeze
    end

    # the immediate parent of this JSI. nil if there is no parent.
    #
    # @return [JSI::Base, nil]
    def jsi_parent_node
      jsi_ptr.root? ? nil : jsi_root_node.jsi_descendent_node(jsi_ptr.parent)
    end

    # ancestor JSI instances from this node up to the root. this node itself is always its own first ancestor.
    #
    # @return [Array<JSI::Base>]
    def jsi_ancestor_nodes
      ancestors = []
      ancestor = jsi_root_node
      ancestors << ancestor

      jsi_ptr.tokens.each do |token|
        ancestor = ancestor[token, as_jsi: true]
        ancestors << ancestor
      end
      ancestors.reverse!.freeze
    end

    # the descendent node at the given pointer
    #
    # @param ptr [JSI::Ptr, #to_ary]
    # @return [JSI::Base]
    def jsi_descendent_node(ptr)
      descendent = Ptr.ary_ptr(ptr).evaluate(self, as_jsi: true)
      descendent
    end

    # yields each token (array index or hash key) identifying a child node.
    # yields nothing if this node is not complex or has no children.
    #
    # @yield [String, Integer] each child token
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_child_token
      # note: overridden by Base::HashNode, Base::ArrayNode
      return to_enum(__method__) { 0 } unless block_given?
      nil
    end

    # Does the given token identify a child of this node?
    #
    # In other words, is the given token an array index or hash key of the instance?
    #
    # Always false if this is not a complex node.
    #
    # @param token [String, Integer]
    # @return [Boolean]
    def jsi_child_token_in_range?(token)
      # note: overridden by Base::HashNode, Base::ArrayNode
      false
    end

    # The child of the {#jsi_node_content} identified by the given token,
    # or `nil` if the token does not identify an existing child.
    #
    # In other words, the element of the instance array at the given index,
    # or the value of the instance hash/object for the given key.
    #
    # @return [Object, nil]
    # @raise [SimpleNodeChildError] if this node is not complex (its instance is not array or hash)
    def jsi_node_content_child(token)
      # note: overridden by Base::HashNode, Base::ArrayNode
      jsi_simple_node_child_error(token)
    end

    # A default value for a child of this node identified by the given token, if schemas describing
    # that child define a default value.
    #
    # If no schema describes a default value for the child (or in the unusual case that multiple
    # schemas define different defaults), the result is `nil`.
    #
    # See also the `use_default` param of {Base#[]}.
    #
    # @param token (see Base#[])
    # @param as_jsi (see Base#[])
    # @return [JSI::Base, nil]
    def jsi_default_child(token, as_jsi: :auto)
      value = jsi_node_content_child(token)

      child_indicated_schemas = jsi_schemas.child_applicator_schemas(token, jsi_node_content)
      child_applied_schemas = child_indicated_schemas.inplace_applicator_schemas(value)

      defaults = Set.new
      child_applied_schemas.each do |subinstance_schema|
        if subinstance_schema.keyword?('default')
          defaults << subinstance_schema.jsi_node_content['default']
        end
      end

      if defaults.size == 1
        # use the default value
        jsi_subinstance_as_jsi(defaults.first, child_applied_schemas, as_jsi) do
          # we are using #dup so that we get a modified copy of self, in which we set dup[token]=default.
          dup.tap { |o| o[token] = defaults.first }[token, as_jsi: true]
        end
      else
        value
      end
    end
    private :jsi_default_child # internals for #[] but idk, could be public

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
      value = jsi_node_content_child(token)

      begin
        child_indicated_schemas = jsi_schemas.child_applicator_schemas(token, jsi_node_content)
        child_applied_schemas = child_indicated_schemas.inplace_applicator_schemas(value)

        if jsi_child_token_in_range?(token)
          jsi_subinstance_as_jsi(value, child_applied_schemas, as_jsi) do
            jsi_subinstance_memos[
              token: token,
              child_indicated_schemas: child_indicated_schemas,
              child_applied_schemas: child_applied_schemas,
              includes: SchemaClasses.includes_for(value),
            ]
          end
        else
          if use_default
            jsi_default_child(token, as_jsi: :auto)
          else
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
      unless jsi_array? || jsi_hash?
        jsi_simple_node_child_error(token)
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
        jsi_indicated_schemas.new_jsi(modified_document,
          uri: jsi_schema_base_uri,
        )
      else
        modified_jsi_root_node = @jsi_root_node.jsi_modified_copy do |root|
          @jsi_ptr.modified_document_copy(root, &block)
        end
        modified_jsi_root_node.jsi_descendent_node(@jsi_ptr)
      end
    end

    # Is the instance an array?
    #
    # An array is typically an instance of the Array class but may be an object that supports
    # [implicit conversion](https://docs.ruby-lang.org/en/master/implicit_conversion_rdoc.html)
    # with a `#to_ary` method.
    #
    # @return [Boolean]
    def jsi_array?
      # note: overridden by Base::ArrayNode
      false
    end

    # Is the instance a ruby Hash (JSON object)?
    #
    # This is typically an instance of the Hash class but may be an object that supports
    # [implicit conversion](https://docs.ruby-lang.org/en/master/implicit_conversion_rdoc.html)
    # with a `#to_hash` method.
    #
    # @return [Boolean]
    def jsi_hash?
      # note: overridden by Base::HashNode
      false
    end

    # validates this JSI's instance against its schemas
    #
    # @return [JSI::Validation::FullResult]
    def jsi_validate
      jsi_indicated_schemas.instance_validate(self)
    end

    # whether this JSI's instance is valid against all of its schemas
    # @return [Boolean]
    def jsi_valid?
      jsi_indicated_schemas.instance_valid?(self)
    end

    # queries this JSI using the [JMESPath Ruby](https://rubygems.org/gems/jmespath) gem.
    # see [https://jmespath.org/](https://jmespath.org/) to learn the JMESPath query language.
    #
    # the JMESPath gem is not a dependency of JSI, so must be installed / added to your Gemfile to use.
    # e.g. `gem 'jmespath', '~> 1.5'`. note that versions below 1.5 are not compatible with JSI.
    #
    # @param expression [String] a [JMESPath](https://jmespath.org/) expression
    # @param runtime_options passed to [JMESPath.search](https://rubydoc.info/gems/jmespath/JMESPath#search-class_method),
    #   though no runtime_options are publicly documented or normally used.
    # @return [Array, Object, nil] query results.
    #   see [JMESPath.search](https://rubydoc.info/gems/jmespath/JMESPath#search-class_method)
    def jmespath_search(expression, **runtime_options)
      Util.require_jmespath

      JMESPath.search(expression, self, **runtime_options)
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
      Util.as_json(jsi_instance, *opt)
    end

    # an opaque fingerprint of this JSI for {Util::FingerprintHash}.
    def jsi_fingerprint
      {
        class: jsi_class,
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        # for instances in documents with schemas:
        jsi_resource_ancestor_uri: jsi_resource_ancestor_uri,
      }
    end
    include Util::FingerprintHash

    private

    def jsi_indicated_schemas=(jsi_indicated_schemas)
      @jsi_indicated_schemas = SchemaSet.ensure_schema_set(jsi_indicated_schemas)
    end

    def jsi_subinstance_memos
      jsi_memomap(:subinstance, key_by: -> (i) { i[:token] }) do |token: , child_indicated_schemas: , child_applied_schemas: , includes: |
        jsi_class = JSI::SchemaClasses.class_for_schemas(child_applied_schemas, includes: includes)
        jsi_class.new(@jsi_document,
          jsi_ptr: @jsi_ptr[token],
          jsi_root_node: @jsi_root_node,
          jsi_indicated_schemas: child_indicated_schemas,
          jsi_schema_base_uri: jsi_resource_ancestor_uri,
          jsi_schema_resource_ancestors: is_a?(Schema) ? jsi_subschema_resource_ancestors : jsi_schema_resource_ancestors,
        )
      end
    end

    def jsi_subinstance_as_jsi(value, subinstance_schemas, as_jsi)
      if [true, false].include?(as_jsi)
        value_as_jsi = as_jsi
      elsif as_jsi == :auto
        complex_value = value.respond_to?(:to_hash) || value.respond_to?(:to_ary)
        schema_value = subinstance_schemas.any?(&:describes_schema?)
        value_as_jsi = complex_value || schema_value
      else
        raise(ArgumentError, "as_jsi must be one of: :auto, true, false")
      end

      if value_as_jsi
        yield
      else
        value
      end
    end

    def jsi_simple_node_child_error(token)
      raise(SimpleNodeChildError, [
        "cannot access a child of this JSI node because this node is not complex",
        "using token: #{token.inspect}",
        "instance: #{jsi_instance.pretty_inspect.chomp}",
      ].join("\n"))
    end
  end
end
