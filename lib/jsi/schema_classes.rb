# frozen_string_literal: true

module JSI
  # A Module associated with a JSI Schema. See {Schema#jsi_schema_module}.
  class SchemaModule < Module
    # @private
    def initialize(schema, &block)
      super(&block)

      @jsi_node = schema

      schema.jsi_schemas.each do |schema_schema|
        extend SchemaClasses.schema_property_reader_module(schema_schema, conflicting_modules: Set[SchemaModule])
      end
    end

    # The schema for which this is the JSI Schema Module
    # @return [Base + Schema]
    def schema
      @jsi_node
    end

    # a URI which refers to the schema. see {Schema#schema_uri}.
    # @return (see Schema#schema_uri)
    def schema_uri
      schema.schema_uri
    end

    # @return [String]
    def inspect
      if name_from_ancestor
        if schema.schema_absolute_uri
          -"#{name_from_ancestor} <#{schema.schema_absolute_uri}> (JSI Schema Module)"
        else
          -"#{name_from_ancestor} (JSI Schema Module)"
        end
      else
        -"(JSI Schema Module: #{schema.schema_uri || schema.jsi_ptr.uri})"
      end
    end

    alias_method :to_s, :inspect

    # invokes {JSI::Schema#new_jsi} on this module's schema, passing the given instance.
    #
    # @param (see JSI::Schema#new_jsi)
    # @return [JSI::Base subclass] a JSI whose content comes from the given instance and whose schemas are
    #   inplace applicators of this module's schema.
    def new_jsi(instance, **kw)
      schema.new_jsi(instance, **kw)
    end

    # See {Schema#schema_content}
    def schema_content
      schema.jsi_node_content
    end

    # See {Schema#instance_validate}
    def instance_validate(instance)
      schema.instance_validate(instance)
    end

    # See {Schema#instance_valid?}
    def instance_valid?(instance)
      schema.instance_valid?(instance)
    end
  end

  # A module to extend the {SchemaModule} of a schema which describes other schemas (a {Schema::DescribesSchema})
  module SchemaModule::DescribesSchemaModule
    # Instantiates the given schema content as a JSI Schema.
    #
    # see {JSI::Schema::DescribesSchema#new_schema}
    #
    # @param (see JSI::Schema::DescribesSchema#new_schema)
    # @yield (see JSI::Schema::DescribesSchema#new_schema)
    # @return [JSI::Base subclass + JSI::Schema] a JSI which is a {JSI::Schema} whose content comes from
    #   the given `schema_content` and whose schemas are inplace applicators of this module's schema
    def new_schema(schema_content, **kw, &block)
      schema.new_schema(schema_content, **kw, &block)
    end

    # (see Schema::DescribesSchema#new_schema_module)
    def new_schema_module(schema_content, **kw, &block)
      schema.new_schema(schema_content, **kw, &block).jsi_schema_module
    end

    # @return [Set<Module>]
    attr_reader :schema_implementation_modules
  end

  # this module is a namespace for building schema classes and schema modules.
  module SchemaClasses
    class << self
      # @api private
      # @return [Set<Module>]
      def includes_for(instance)
        includes = Set[]
        includes << Base::ArrayNode if instance.respond_to?(:to_ary)
        includes << Base::HashNode if instance.respond_to?(:to_hash)
        includes << Base::StringNode if instance.respond_to?(:to_str)
        includes.freeze
      end

      # a JSI Schema Class which represents the given schemas.
      # an instance of the class is a JSON Schema instance described by all of the given schemas.
      # @api private
      # @param schemas [Enumerable<JSI::Schema>] schemas which the class will represent
      # @param includes [Enumerable<Module>] modules which will be included on the class
      # @return [Class subclassing JSI::Base]
      def class_for_schemas(schemas, includes: , mutable: )
        @class_for_schemas_map[
          schemas: SchemaSet.ensure_schema_set(schemas),
          includes: Util.ensure_module_set(includes),
          mutable: mutable,
        ]
      end

      private def class_for_schemas_compute(schemas: , includes: , mutable: )
          Class.new(Base) do
            define_singleton_method(:jsi_class_schemas) { schemas }
            define_method(:jsi_schemas) { schemas }

            define_singleton_method(:jsi_class_includes) { includes }

            mutability_module = mutable ? Base::Mutable : Base::Immutable
            conflicting_modules = Set[JSI::Base, mutability_module] + includes + schemas.map(&:jsi_schema_module)

            include(mutability_module)

            reader_modules = schemas.map do |schema|
              JSI::SchemaClasses.schema_property_reader_module(schema, conflicting_modules: conflicting_modules)
            end
            reader_modules.each { |m| include m }
            readers = reader_modules.map(&:jsi_property_readers).inject(Set[], &:merge).freeze
            define_method(:jsi_property_readers) { readers }
            define_singleton_method(:jsi_property_readers) { readers }

            if mutable
              writer_modules = schemas.map do |schema|
                JSI::SchemaClasses.schema_property_writer_module(schema, conflicting_modules: conflicting_modules)
              end
              writer_modules.each { |m| include(m) }
            end

            includes.each { |m| include(m) }
            schemas.each { |schema| include(schema.jsi_schema_module) }
            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            self
          end
      end

      # a subclass of MetaschemaNode::BootstrapSchema with the given modules included
      # @api private
      # @param modules [Set<Module>] schema implementation modules
      # @return [Class]
      def bootstrap_schema_class(modules)
        @bootstrap_schema_class_map[
          modules: Util.ensure_module_set(modules),
        ]
      end

      private def bootstrap_schema_class_compute(modules: )
          Class.new(MetaschemaNode::BootstrapSchema) do
            define_singleton_method(:schema_implementation_modules) { modules }
            define_method(:schema_implementation_modules) { modules }
            modules.each { |mod| include(mod) }

            self
          end
      end

      # see {Schema#jsi_schema_module}
      # @api private
      # @return [Module + SchemaModule]
      def module_for_schema(schema)
        Schema.ensure_schema(schema)
        raise(Bug, "non-Base schema cannot have schema module: #{schema}") unless schema.is_a?(Base)
        @schema_module_map[schema: schema]
      end

      private def schema_module_compute(schema: )
        SchemaModule.new(schema)
      end

      # @deprecated after v0.7
      def accessor_module_for_schema(schema, conflicting_modules: , setters: true)
        Module.new do
          include SchemaClasses.schema_property_reader_module(schema, conflicting_modules: conflicting_modules)
          include SchemaClasses.schema_property_writer_module(schema, conflicting_modules: conflicting_modules) if setters
        end
      end

      # a module of readers for described property names of the given schema.
      #
      # @api private
      # @param schema [JSI::Schema] a schema for which to define readers for any described property names
      # @param conflicting_modules [Enumerable<Module>] an array of modules (or classes) which
      #   may be used alongside the accessor module. methods defined by any conflicting_module
      #   will not be defined as accessors.
      # @return [Module]
      def schema_property_reader_module(schema, conflicting_modules: )
        Schema.ensure_schema(schema)
        @schema_property_reader_module_map[schema: schema, conflicting_modules: conflicting_modules]
      end

      private def schema_property_reader_module_compute(schema: , conflicting_modules: )
          Module.new do
            define_singleton_method(:inspect) { '(JSI Schema Property Reader Module)' }

            readers = schema.described_object_property_names.select do |name|
              Util.ok_ruby_method_name?(name) &&
                !conflicting_modules.any? { |m| m.method_defined?(name) || m.private_method_defined?(name) }
            end.to_set.freeze

            define_singleton_method(:jsi_property_readers) { readers }

            readers.each do |property_name|
              define_method(property_name) do |**kw, &block|
                self[property_name, **kw, &block]
              end
            end
          end
      end

      # a module of writers for described property names of the given schema.
      # @api private
      def schema_property_writer_module(schema, conflicting_modules: )
        Schema.ensure_schema(schema)
        @schema_property_writer_module_map[schema: schema, conflicting_modules: conflicting_modules]
      end

      private def schema_property_writer_module_compute(schema: , conflicting_modules: )
          Module.new do
            define_singleton_method(:inspect) { '(JSI Schema Property Writer Module)' }

            writers = schema.described_object_property_names.select do |name|
              writer = "#{name}="
              Util.ok_ruby_method_name?(name) &&
                !conflicting_modules.any? { |m| m.method_defined?(writer) || m.private_method_defined?(writer) }
            end.to_set.freeze

            define_singleton_method(:jsi_property_writers) { writers }

            writers.each do |property_name|
                  define_method("#{property_name}=") do |value|
                    self[property_name] = value
                  end
            end
          end
      end
    end

    @class_for_schemas_map          = Hash.new { |h, k| h[k] = class_for_schemas_compute(**k) }
    @bootstrap_schema_class_map      = Hash.new { |h, k| h[k] = bootstrap_schema_class_compute(**k) }
    @schema_module_map                = Hash.new { |h, k| h[k] = schema_module_compute(**k) }
    @schema_property_reader_module_map = Hash.new { |h, k| h[k] = schema_property_reader_module_compute(**k) }
    @schema_property_writer_module_map = Hash.new { |h, k| h[k] = schema_property_writer_module_compute(**k) }
  end

  # connecting {SchemaModule}s via {SchemaModule::Connection}s
  module SchemaModule::Connects
    attr_reader :jsi_node

    # a name relative to a named schema module of an ancestor schema.
    # for example, if `Foos = JSI::JSONSchemaDraft07.new_schema_module({'items' => {}})`
    # then the module `Foos.items` will have a name_from_ancestor of `"Foos.items"`
    # @api private
    # @return [String, nil]
    def name_from_ancestor
      named_ancestor_schema, tokens = named_ancestor_schema_tokens
      return nil unless named_ancestor_schema

      name = named_ancestor_schema.jsi_schema_module.name
      ancestor = named_ancestor_schema
      tokens.each do |token|
        if ancestor.jsi_property_readers.include?(token)
          name += ".#{token}"
        elsif [String, Numeric, TrueClass, FalseClass, NilClass].any? { |m| token.is_a?(m) }
          name += "[#{token.inspect}]"
        else
          return nil
        end
        ancestor = ancestor[token]
      end
      name
    end

    # Subscripting a JSI schema module or a {SchemaModule::Connection} will subscript its node, and
    # if the result is a JSI::Schema, return the JSI Schema module of that schema; if it is a JSI::Base,
    # return a SchemaModule::Connection; or if it is another value (a basic type), return that value.
    #
    # @param token [Object]
    # @yield If the token identifies a schema and a block is given,
    #   it is evaluated in the context of the schema's JSI schema module
    #   using [Module#module_exec](https://ruby-doc.org/core/Module.html#method-i-module_exec).
    # @return [Module, SchemaModule::Connection, Object]
    def [](token, **kw, &block)
      raise(ArgumentError) unless kw.empty? # TODO remove eventually (keyword argument compatibility)
      sub = @jsi_node[token]
      if sub.is_a?(JSI::Schema)
        sub.jsi_schema_module_exec(&block) if block
        sub.jsi_schema_module
      elsif block
        raise(ArgumentError, "block given but token #{token.inspect} does not identify a schema")
      elsif sub.is_a?(JSI::Base)
        SchemaModule::Connection.new(sub)
      else
        sub
      end
    end

    private

    # @return [Array<JSI::Schema, Array>, nil]
    def named_ancestor_schema_tokens
      schema_ancestors = @jsi_node.jsi_ancestor_nodes
      named_ancestor_schema = schema_ancestors.detect { |jsi| jsi.is_a?(JSI::Schema) && jsi.jsi_schema_module.name }
      return nil unless named_ancestor_schema
      tokens = @jsi_node.jsi_ptr.relative_to(named_ancestor_schema.jsi_ptr).tokens
      [named_ancestor_schema, tokens]
    end
  end

  class SchemaModule
    include Connects
  end

  # A JSI Schema Module is a module which represents a schema. A SchemaModule::Connection represents
  # a node in a schema's document which is not a schema, such as the 'properties'
  # object (which contains schemas but is not a schema).
  #
  # instances of this class act as a stand-in to allow users to subscript or call property accessors on
  # schema modules to refer to their subschemas' schema modules.
  #
  # A SchemaModule::Connection has readers for property names described by the node's schemas.
  class SchemaModule::Connection
    include SchemaModule::Connects

    # @param node [JSI::Base]
    def initialize(node)
      raise(Bug, "node must be JSI::Base: #{node.pretty_inspect.chomp}") unless node.is_a?(JSI::Base)
      raise(Bug, "node must not be JSI::Schema: #{node.pretty_inspect.chomp}") if node.is_a?(JSI::Schema)
      @jsi_node = node
      node.jsi_schemas.each do |schema|
        extend(JSI::SchemaClasses.schema_property_reader_module(schema, conflicting_modules: [SchemaModule::Connection]))
      end
    end

    # @return [String]
    def inspect
      if name_from_ancestor
        -"#{name_from_ancestor} (#{self.class})"
      else
        -"(#{self.class}: #{@jsi_node.jsi_ptr.uri})"
      end
    end

    alias_method :to_s, :inspect
  end
end
