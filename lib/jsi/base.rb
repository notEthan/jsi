# frozen_string_literal: true

module JSI
  # A JSI::Base instance represents a node in a JSON document (its {#jsi_document}) at a particular
  # location (its {#jsi_ptr}), described by any number of JSON Schemas (its {#jsi_schemas}).
  #
  # JSI::Base is an abstract base class. The subclasses used to instantiate JSIs are dynamically created as
  # needed for a given instance.
  #
  # These subclasses are generally intended to be ignored by applications using this library - the purpose
  # they serve is to include modules relevant to the instance. The modules these classes include are:
  #
  # - the {Schema#jsi_schema_module} of each schema which describes the instance
  # - {Base::HashNode}, {Base::ArrayNode}, or {Base::StringNode} if the instance is
  #   a hash/object, array, or string
  # - Modules defining accessor methods for property names described by the schemas
  class Base
    autoload :ArrayNode, 'jsi/base/node'
    autoload :HashNode, 'jsi/base/node'
    autoload :StringNode, 'jsi/base/node'
    autoload(:Mutable, 'jsi/base/mutability')
    autoload(:Immutable, 'jsi/base/mutability')

    include Schema::SchemaAncestorNode

    # An exception raised when attempting to access a child of a node which cannot have children.
    # A complex node can have children, a simple node cannot.
    class SimpleNodeChildError < StandardError
    end

    class ChildNotPresent < StandardError
    end

    class << self
      # A string indicating the schema module name
      # and/or schema URI of each schema the class represents.
      # @return [String]
      def inspect
        if !respond_to?(:jsi_class_schemas)
          super
        else
          schema_names = jsi_class_schemas.map do |schema|
            mod_name = schema.jsi_schema_module_name_from_ancestor
            if mod_name && schema.schema_absolute_uri
              "#{mod_name} <#{schema.schema_absolute_uri}>"
            elsif mod_name
              mod_name
            elsif schema.schema_uri
              schema.schema_uri.to_s
            else
              schema.jsi_ptr.uri.to_s
            end
          end

          if schema_names.empty?
            "(JSI Schema Class for 0 schemas#{jsi_class_includes.map { |n| " + #{n}" }.join})"
          else
            -"(JSI Schema Class: #{(schema_names + jsi_class_includes.map(&:name)).join(' + ')})"
          end
        end
      end

      def to_s
        inspect
      end

      # A constant name of this class. This is generated from any schema module name or URI of each schema
      # this class represents, or random characters.
      #
      # this generated name is not too pretty but can be more helpful than an anonymous class, especially
      # in error messages.
      #
      # @return [String]
      def name
        return super if instance_variable_defined?(:@tried_to_name)
        @tried_to_name = true
        return super unless respond_to?(:jsi_class_schemas)
        alnum = proc { |id| (id % 36**4).to_s(36).rjust(4, '0').upcase }
        schema_names = jsi_class_schemas.map do |schema|
          named_ancestor_schema, tokens = schema.jsi_schema_module.send(:named_ancestor_schema_tokens)
          if named_ancestor_schema
            [named_ancestor_schema.jsi_schema_module_name, *tokens].join('_')
          elsif schema.schema_uri
            schema.schema_uri.to_s
          else
            [alnum[schema.jsi_root_node.__id__], *schema.jsi_ptr.tokens].join('_')
          end
        end
        includes_names = jsi_class_includes.map { |m| m.name.sub(/\AJSI::Base::/, '').gsub(Util::RUBY_REJECT_NAME_RE, '_') }
        if schema_names.any?
          parts = schema_names.compact.sort.map { |n| 'X' + n.to_s }
          parts += includes_names
          const_name = Util.const_name_from_parts(parts, join: '__')
          const_name += "__" + alnum[__id__] if SchemaClasses.const_defined?(const_name)
        else
          const_name = (['X' + alnum[__id__]] + includes_names).join('__')
        end
        # collisions are technically possible though vanishingly unlikely
        SchemaClasses.const_set(const_name, self) unless SchemaClasses.const_defined?(const_name)
        super
      end
    end

    # initializes a JSI whose instance is in the given document at the given pointer.
    #
    # this is a private api - users should look elsewhere to instantiate JSIs, in particular:
    #
    # - {JSI.new_schema} and {Schema::MetaSchema#new_schema} to instantiate schemas
    # - {Schema#new_jsi} to instantiate schema instances
    #
    # @api private
    # @param jsi_document [Object] the document containing the instance
    # @param jsi_ptr [JSI::Ptr] a pointer pointing to the JSI's instance in the document
    # @param jsi_schema_base_uri [Addressable::URI] see {SchemaSet#new_jsi} param uri
    # @param jsi_schema_resource_ancestors [Array<JSI::Base + JSI::Schema>]
    # @param jsi_root_node [JSI::Base] the JSI of the root of the document containing this JSI
    def initialize(jsi_document,
        jsi_ptr: Ptr[],
        jsi_indicated_schemas: ,
        jsi_schema_base_uri: nil,
        jsi_schema_resource_ancestors: Util::EMPTY_ARY,
        jsi_schema_registry: ,
        jsi_content_to_immutable: ,
        jsi_root_node: nil
    )
      #chkbug fail(Bug, "no #jsi_schemas") unless respond_to?(:jsi_schemas)

      self.jsi_document = jsi_document
      self.jsi_ptr = jsi_ptr
      self.jsi_indicated_schemas = jsi_indicated_schemas
      self.jsi_schema_base_uri = jsi_schema_base_uri
      self.jsi_schema_resource_ancestors = jsi_schema_resource_ancestors
      self.jsi_schema_registry = jsi_schema_registry
      @jsi_content_to_immutable = jsi_content_to_immutable
      if @jsi_ptr.root?
        #chkbug fail(Bug, "jsi_root_node specified for root JSI") if jsi_root_node
        @jsi_root_node = self
      else
        #chkbug fail(Bug, "jsi_root_node is not JSI::Base") if !jsi_root_node.is_a?(JSI::Base)
        #chkbug fail(Bug, "jsi_root_node ptr is not root") if !jsi_root_node.jsi_ptr.root?
        @jsi_root_node = jsi_root_node
      end

      jsi_memomaps_initialize
      jsi_mutability_initialize

      super()

      if jsi_instance.is_a?(JSI::Base)
        raise(TypeError, "a JSI::Base instance must not be another JSI::Base. received: #{jsi_instance.pretty_inspect.chomp}")
      end
    end

    # @!method jsi_schemas
    #   The set of schemas that describe this instance.
    #   These are the applicator schemas that apply to this instance, the result of inplace application
    #   of our {#jsi_indicated_schemas}.
    #   @return [JSI::SchemaSet]
    # note: defined on subclasses by JSI::SchemaClasses.class_for_schemas


    # document containing the instance of this JSI at our {#jsi_ptr}
    attr_reader :jsi_document

    # {JSI::Ptr} pointing to this JSI's instance within our {#jsi_document}
    # @return [JSI::Ptr]
    attr_reader :jsi_ptr

    # Comes from the param `to_immutable` of {SchemaSet#new_jsi} (or other `new_jsi` /
    # `new_schema` / `new_schema_module` method).
    # Immutable JSIs use this when instantiating a modified copy so its instance is also immutable.
    # @return [#call, nil]
    attr_reader(:jsi_content_to_immutable)

    # the JSI at the root of this JSI's document
    # @return [JSI::Base]
    attr_reader :jsi_root_node

    # the content of this node in our {#jsi_document} at our {#jsi_ptr}. the same as {#jsi_instance}.
    def jsi_node_content
      # stub method for doc, overridden by Mutable/Immutable
    end

    # The JSON schema instance this JSI represents - the underlying JSON data used to instantiate this JSI.
    # The same as {#jsi_node_content} - 'node content' is usually preferable terminology, to avoid
    # ambiguity in the heavily overloaded term 'instance'.
    def jsi_instance
      jsi_node_content
    end

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
    # @param propertyNames [Boolean] Whether to also yield each object property
    #   name (Hash key) of any descendent which is a hash/object.
    #   These are described by `propertyNames` subshemas of that object's schemas.
    #   They are not actual descendents of this node.
    #   See {HashNode#jsi_each_propertyName}.
    # @yield [JSI::Base] each descendent node, starting with self
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_descendent_node(propertyNames: false, &block)
      return to_enum(__method__, propertyNames: propertyNames) unless block

      yield self

      if propertyNames && is_a?(HashNode)
        jsi_each_propertyName do |propertyName|
          propertyName.jsi_each_descendent_node(propertyNames: propertyNames, &block)
        end
      end

      jsi_each_child_token do |token|
        jsi_child_node(token).jsi_each_descendent_node(propertyNames: propertyNames, &block)
      end

      nil
    end

    # yields each descendent of this node that is a JSI Schema
    # @yield [Base + Schema]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def jsi_each_descendent_schema(&block)
      return(to_enum(__method__)) unless block_given?

      # note: this never yields self; if self is a Schema, Schema#jsi_each_descendent_schema overrides this method
      jsi_each_child_token do |token|
        jsi_child(token, as_jsi: true).jsi_each_descendent_schema(&block)
      end
    end

    # yields each descendent of this node within the same resource that is a Schema
    # @yield [Schema]
    def jsi_each_descendent_schema_same_resource(&block)
      return(to_enum(__method__)) unless block_given?

      jsi_each_child_token do |token|
        child = jsi_child_node(token)
        if !child.is_a?(Schema) || !child.schema_resource_root?
          # note: if child is a Schema, Schema#jsi_each_descendent_schema_same_resource overrides Base
          child.jsi_each_descendent_schema_same_resource(&block)
        end
      end
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
            v = jsi_child_node(token)
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
            v = jsi_child_node(token).jsi_select_descendents_leaf_first(&block)
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
          parent = parent.jsi_child_node(token)
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
        ancestor = ancestor.jsi_child_node(token)
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

    # A shorthand alias for {#jsi_descendent_node}.
    #
    # Note that, though more convenient to type, using an operator whose meaning may not be intuitive
    # to a reader could impair readability of code.
    #
    # examples:
    #
    #     my_jsi / ['foo', 'bar']
    #     my_jsi / %w(foo bar)
    #     my_schema / JSI::Ptr['additionalProperties']
    #     my_schema / %w(properties foo items additionalProperties)
    #
    # @param (see #jsi_descendent_node)
    # @return (see #jsi_descendent_node)
    def /(ptr)
      jsi_descendent_node(ptr)
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
    def jsi_child_token_present?(token)
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

    # A child JSI node, or the child of our {#jsi_instance}, identified by the given token.
    # The token must identify an existing child; behavior if the child does not exist is undefined.
    #
    # @param token (see Base#[])
    # @param as_jsi (see Base#[])
    # @return [JSI::Base, Object]
    def jsi_child(token, as_jsi: )
      child_content = jsi_node_content_child(token)

      child_indicated_schemas = @child_indicated_schemas_map[token: token, content: jsi_node_content]
      child_applied_schemas = @child_applied_schemas_map[token: token, child_indicated_schemas: child_indicated_schemas, child_content: child_content]

      jsi_child_as_jsi(child_content, child_applied_schemas, as_jsi) do
        @child_node_map[
          token: token,
          child_indicated_schemas: child_indicated_schemas,
          child_applied_schemas: child_applied_schemas,
          includes: SchemaClasses.includes_for(child_content),
        ]
      end
    end
    private :jsi_child # internals for #[] but idk, could be public

    # @param token An array index or Hash/object property name identifying a present child of this node
    # @return [JSI::Base]
    # @raise [Base::ChildNotPresent]
    def jsi_child_node(token)
      if !jsi_child_token_present?(token)
        raise(ChildNotPresent, -"token does not identify a child that is present: #{token.inspect}\nself = #{pretty_inspect.chomp}")
      end
      jsi_child(token, as_jsi: true)
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
    def jsi_default_child(token, as_jsi: )
      child_content = jsi_node_content_child(token)

      child_indicated_schemas = @child_indicated_schemas_map[token: token, content: jsi_node_content]
      child_applied_schemas = @child_applied_schemas_map[token: token, child_indicated_schemas: child_indicated_schemas, child_content: child_content]

      defaults = Set.new
      child_applied_schemas.each do |child_schema|
        defaults.merge(child_schema.dialect_invoke_each(:default))
      end

      if defaults.size == 1
        # use the default value
        jsi_child_as_jsi(defaults.first, child_applied_schemas, as_jsi) do
          jsi_modified_copy do |i|
            i.dup.tap { |i_dup| i_dup[token] = defaults.first }
          end.jsi_child_node(token)
        end
      else
        child_content
      end
    end
    private :jsi_default_child # internals for #[] but idk, could be public

    # subscripts to return a child value identified by the given token.
    #
    # @param token [String, Integer, Range, Object] Identifies the child or children to return.
    #   Typically an array index or hash key (JSON object property name) of the instance.
    #   For an array instance, this may also be a Range (in which case an Array of children is returned)
    #   or a negative index; these behave as Array#[] does.
    # @param as_jsi [:auto, true, false] (default is `:auto`)
    #   Whether to return the child as a JSI. One of:
    #
    #   - `:auto`: By default a JSI will be returned when either:
    #
    #     - the result is a complex value (responds to #to_ary or #to_hash)
    #     - the result is a schema (including true/false schemas)
    #
    #     The plain content is returned when it is a simple type.
    #
    #   - true: the result value will always be returned as a JSI. the {#jsi_schemas} of the result may be
    #     empty if no schemas describe the instance.
    #   - false: the result value will always be the plain instance.
    #
    #   note that nil is returned (regardless of as_jsi) when there is no value to return because the token
    #   is not a hash key or array index of the instance and no default value applies.
    #   (one exception is when this JSI's instance is a Hash with a default or default_proc, which has
    #   unspecified behavior.)
    # @param use_default [true, false] (default is `false`)
    #   Whether to return a schema default value when the token refers to a child that is not in the document.
    #   If the token is not an array index or hash key of the instance, and one schema for the child
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
    # @return [Base, Object, Array, nil] the child or children identified by `token`
    def [](token, as_jsi: jsi_child_as_jsi_default, use_default: jsi_child_use_default_default)
      # note: overridden by Base::HashNode, Base::ArrayNode
      jsi_simple_node_child_error(token)
    end

    # The default value for the param `as_jsi` of {#[]}, controlling whether a child is returned as a JSI instance.
    # @return [:auto, true, false] a valid value of the `as_jsi` param of {#[]}
    def jsi_child_as_jsi_default
      :auto
    end

    # The default value for the param `use_default` of {#[]}, controlling whether a schema default value is
    # returned when a token refers to a child that is not in the document.
    # @return [true, false] a valid value of the `use_default` param of {#[]}
    def jsi_child_use_default_default
      false
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

    # Is this JSI described by the given schema (or schema module)?
    #
    # @param schema [Schema, SchemaModule]
    # @return [Boolean]
    def described_by?(schema)
      if schema.is_a?(Schema)
        jsi_schemas.include?(schema)
      elsif schema.is_a?(SchemaModule)
        jsi_schema_modules.include?(schema)
      else
        raise(TypeError, "expected a Schema or Schema Module; got: #{schema.pretty_inspect.chomp}")
      end
    end

    # Is this a JSI Schema?
    # @return [Boolean]
    def jsi_is_schema?
      false
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
        modified_document = @jsi_ptr.modified_document_copy(@jsi_document, &block)
        modified_jsi_root_node = @jsi_root_node.jsi_indicated_schemas.new_jsi(modified_document,
          uri: @jsi_root_node.jsi_schema_base_uri,
          register: false, # default is already false but this is a place to be explicit
          schema_registry: jsi_schema_registry,
          mutable: jsi_mutable?,
          to_immutable: jsi_content_to_immutable,
        )
        modified_jsi_root_node.jsi_descendent_node(@jsi_ptr)
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

    # Is this JSI mutable?
    # @return [Boolean]
    def jsi_mutable?
      # note: overridden by Base::Mutable / Immutable
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

    # A JSI whose node content is a duplicate of this JSI's (using its #dup).
    #
    # Note that immutable JSIs are not made mutable with #dup.
    # The content's #dup may return an unfrozen copy, but instantiating a modified
    # copy of this JSI involves transforming the content to immutable again
    # (using our {#jsi_content_to_immutable}).
    # @return [Base]
    def dup
      jsi_modified_copy(&:dup)
    end

    # A string indicating this JSI's schemas, briefly, and its content.
    #
    # If described by a schema with a named schema module, that is shown.
    # The number of schemas describing this JSI is indicated.
    #
    # If this JSI is a simple type, the node's content is inspected; if complex, its children are inspected.
    # @return [String]
    def inspect
      -"\#<#{jsi_object_group_text.join(' ')} #{jsi_instance.inspect}>"
    end

    # See #inspect
    def to_s
      inspect
    end

    # pretty-prints a representation of this JSI to the given printer
    # @return [void]
    def pretty_print(q)
      q.text '#<'
      q.text jsi_object_group_text.join(' ')
      q.group(2) {
          q.breakable ' '
          q.pp jsi_instance
      }
      q.breakable ''
      q.text '>'
    end

    # @private
    # @return [Array<String>]
    def jsi_object_group_text
      jsi_schemas = self.jsi_schemas || Util::EMPTY_SET # for debug during MSN initialize, may not be set yet
      schemas_priorities = jsi_schemas.each_with_index.map do |schema, i|
        if schema.describes_schema?
          [0, i, schema]
        elsif schema.jsi_schema_module_name
          [1, i, schema]
        elsif schema.jsi_schema_module_name_from_ancestor
          [2, i, schema]
        elsif schema.schema_absolute_uri
          [3, i, schema]
        elsif schema.schema_uri
          [4, i, schema]
        elsif !schema.respond_to?(:to_hash)
          # boolean
          [9, i, schema]
        elsif schema.empty?
          [8, i, schema]
        elsif schema.all? { |k, _| k == '$ref' || k == '$dynamicRef' }
          [7, i, schema]
        else
          [5, i, schema]
        end
      end.sort

      schema_names = []
      schemas_priorities.each do |(priority, _idx, schema)|
        if priority == 0 || (priority == schemas_priorities.first.first && schema_names.size < 2)
          name = schema.jsi_schema_module_name_from_ancestor || schema.schema_uri
          name ||= schema.jsi_ptr.uri if priority == 0
          schema_names << name if name
        end
      end

      if schema_names.empty?
        schemas_txt = -"*#{jsi_schemas.size}"
      elsif schema_names.size == jsi_schemas.size
        schemas_txt = -" (#{schema_names.join(' + ')})"
      else
        schemas_txt = -" (#{schema_names.join(' + ')} + #{jsi_schemas.size - schema_names.size})"
      end

      if (is_a?(ArrayNode) || is_a?(HashNode)) && ![Array, Hash].include?(jsi_node_content.class)
        if jsi_node_content.respond_to?(:jsi_object_group_text)
          content_txt = jsi_node_content.jsi_object_group_text
        else
          content_txt = jsi_node_content.class.to_s
        end
      else
        content_txt = nil
      end

      [
        -"JSI#{is_a?(MetaSchemaNode) ? ":MSN" : ""}#{schemas_txt}",
        is_a?(Schema::MetaSchema) ? "Meta-Schema" : is_a?(Schema) ? "Schema" : nil,
        *content_txt,
      ].compact.freeze
    end

    # A structure coerced to JSONifiable types from the instance content.
    # Calls {Util.as_json} with the instance and any given options.
    def as_json(options = {})
      Util.as_json(jsi_instance, **options)
    end

    # A JSON encoded string of the instance content.
    # Calls {Util.to_json} with the instance and any given options.
    # @return [String]
    def to_json(options = {})
      Util.to_json(jsi_instance, options)
    end

    # see {Util::Private::FingerprintHash}
    # @api private
    def jsi_fingerprint
      {
        class: JSI::Base,
        jsi_schemas: jsi_schemas,
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        # for instances in documents with schemas:
        jsi_resource_ancestor_uri: jsi_resource_ancestor_uri,
        # different registries mean references may resolve to different resources so must not be equal
        jsi_schema_registry: jsi_schema_registry,
      }.freeze
    end

    private

    BY_TOKEN = proc { |i| i[:token] }

    def jsi_memomaps_initialize
      @child_indicated_schemas_map = jsi_memomap(key_by: BY_TOKEN, &method(:jsi_child_indicated_schemas_compute))
      @child_applied_schemas_map = jsi_memomap(key_by: BY_TOKEN, &method(:jsi_child_applied_schemas_compute))
      @child_node_map = jsi_memomap(key_by: BY_TOKEN, &method(:jsi_child_node_compute))
    end

    def jsi_indicated_schemas=(jsi_indicated_schemas)
      #chkbug fail(Bug) unless jsi_indicated_schemas.is_a?(SchemaSet)
      @jsi_indicated_schemas = jsi_indicated_schemas
    end

    def jsi_child_node_compute(token: , child_indicated_schemas: , child_applied_schemas: , includes: )
        jsi_class = JSI::SchemaClasses.class_for_schemas(child_applied_schemas,
          includes: includes,
          mutable: jsi_mutable?,
        )
        jsi_class.new(@jsi_document,
          jsi_ptr: @jsi_ptr[token],
          jsi_indicated_schemas: child_indicated_schemas,
          jsi_schema_base_uri: jsi_resource_ancestor_uri,
          jsi_schema_resource_ancestors: is_a?(Schema) ? jsi_subschema_resource_ancestors : jsi_schema_resource_ancestors,
          jsi_schema_registry: jsi_schema_registry,
          jsi_content_to_immutable: @jsi_content_to_immutable,
          jsi_root_node: @jsi_root_node,
        )
    end

    def jsi_child_indicated_schemas_compute(token: , content: )
      if jsi_indicated_schemas.any? { |is| is.dialect_invoke_each(:application_requires_evaluated).any? }
        # if application_requires_evaluated, in-place application needs to collect token evaluation
        # recursively to inform child application, so must be recomputed.
        jsi_indicated_schemas.each_yield_set do |is, y|
          is.each_inplace_child_applicator_schema(token, content, &y)
        end
      else
        # if token evaluation does not need to be collected, use our already-computed #jsi_schemas.
        jsi_schemas.each_yield_set do |s, y|
          s.each_child_applicator_schema(token, content, &y)
        end
      end
    end

    def jsi_child_applied_schemas_compute(token: , child_indicated_schemas: , child_content: )
      child_indicated_schemas.each_yield_set do |cis, y|
        cis.each_inplace_applicator_schema(child_content, &y)
      end
    end

    def jsi_child_as_jsi(child_content, child_schemas, as_jsi)
      if [true, false].include?(as_jsi)
        child_as_jsi = as_jsi
      elsif as_jsi == :auto
        child_is_complex = child_content.respond_to?(:to_hash) || child_content.respond_to?(:to_ary)
        child_is_schema = child_schemas.any?(&:describes_schema?)
        child_as_jsi = child_is_complex || child_is_schema
      else
        raise(ArgumentError, "as_jsi must be one of: :auto, true, false")
      end

      if child_as_jsi
        yield
      else
        child_content
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
