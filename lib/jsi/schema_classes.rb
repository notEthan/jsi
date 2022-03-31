# frozen_string_literal: true

module JSI
  # JSI Schema Modules are extended with JSI::SchemaModule
  module SchemaModule
    # @!method schema
    #   the schema of which this is the JSI Schema Module
    #   @return [Schema]
    # note: defined on JSI Schema Module by JSI::SchemaClasses.module_for_schema


    # a URI which refers to the schema. see {Schema#schema_uri}.
    # @return (see Schema#schema_uri)
    def schema_uri
      schema.schema_uri
    end

    # @return [String]
    def inspect
      if name_from_ancestor
        "#{name_from_ancestor} (JSI Schema Module)"
      else
        "(JSI Schema Module: #{schema.schema_uri || schema.jsi_ptr.uri})"
      end
    end

    alias_method :to_s, :inspect

    # invokes {JSI::Schema#new_jsi} on this module's schema, passing the given instance.
    #
    # @param (see JSI::Schema#new_jsi)
    # @return [JSI::Base] a JSI whose instance is the given instance
    def new_jsi(instance, **kw)
      schema.new_jsi(instance, **kw)
    end
  end

  # a module to extend the JSI Schema Module of a schema which describes other schemas
  module DescribesSchemaModule
    # instantiates the given schema content as a JSI Schema.
    #
    # see {JSI::Schema::DescribesSchema#new_schema}
    #
    # @param (see JSI::Schema::DescribesSchema#new_schema)
    # @return [JSI::Base, JSI::Schema] a JSI whose instance is the given schema_content and whose schemas
    #   consist of this module's schema.
    def new_schema(schema_content, **kw)
      schema.new_schema(schema_content, **kw)
    end

    # instantiates a given schema object as a JSI Schema and returns its JSI Schema Module.
    #
    # shortcut to chain {JSI::Schema::DescribesSchema#new_schema} + {Schema#jsi_schema_module}.
    #
    # @param (see JSI::Schema::DescribesSchema#new_schema)
    # @return [Module, JSI::SchemaModule] the JSI Schema Module of the schema
    def new_schema_module(schema_content, **kw)
      schema.new_schema(schema_content, **kw).jsi_schema_module
    end

    # @return [Set<Module>]
    attr_reader :schema_implementation_modules
  end

  # this module is a namespace for building schema classes and schema modules.
  module SchemaClasses
    extend Util::Memoize

    class << self
      # @api private
      # @return [Set<Module>]
      def includes_for(instance)
        includes = Set[]
        includes << Base::ArrayNode if instance.respond_to?(:to_ary)
        includes << Base::HashNode if instance.respond_to?(:to_hash)
        includes.freeze
      end

      # a JSI Schema Class which represents the given schemas.
      # an instance of the class is a JSON Schema instance described by all of the given schemas.
      # @api private
      # @param schemas [Enumerable<JSI::Schema>] schemas which the class will represent
      # @param includes [Enumerable<Module>] modules which will be included on the class
      # @return [Class subclassing JSI::Base]
      def class_for_schemas(schemas, includes: )
        schemas = SchemaSet.ensure_schema_set(schemas)
        includes = Util.ensure_module_set(includes)

        jsi_memoize(:class_for_schemas, schemas: schemas, includes: includes) do |schemas: , includes: |
          Class.new(Base) do
            define_singleton_method(:jsi_class_schemas) { schemas }
            define_method(:jsi_schemas) { schemas }
            includes.each { |m| include(m) }
            schemas.each { |schema| include(schema.jsi_schema_module) }
            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            self
          end
        end
      end

      # a subclass of MetaschemaNode::BootstrapSchema with the given modules included
      # @api private
      # @param modules [Set<Module>] schema implementation modules
      # @return [Class]
      def bootstrap_schema_class(modules)
        modules = Util.ensure_module_set(modules)
        jsi_memoize(__method__, modules: modules) do |modules: |
          Class.new(MetaschemaNode::BootstrapSchema) do
            define_singleton_method(:schema_implementation_modules) { modules }
            define_method(:schema_implementation_modules) { modules }
            modules.each { |mod| include(mod) }

            self
          end
        end
      end

      # see {Schema#jsi_schema_module}
      # @api private
      # @return [Module]
      def module_for_schema(schema)
        Schema.ensure_schema(schema)
        jsi_memoize(:module_for_schema, schema: schema) do |schema: |
          Module.new do
            begin
              define_singleton_method(:schema) { schema }

              extend SchemaModule

              schema.jsi_schema_instance_modules.each do |mod|
                include(mod)
              end

              accessor_module = JSI::SchemaClasses.accessor_module_for_schema(schema,
                conflicting_modules: Set[JSI::Base, JSI::Base::ArrayNode, JSI::Base::HashNode] +
                  schema.jsi_schema_instance_modules,
              )
              include accessor_module

              define_singleton_method(:jsi_property_accessors) { accessor_module.jsi_property_accessors }

              @possibly_schema_node = schema
              extend(SchemaModulePossibly)
              schema.jsi_schemas.each do |schema_schema|
                extend JSI::SchemaClasses.accessor_module_for_schema(schema_schema,
                  conflicting_modules: Set[Module, SchemaModule, SchemaModulePossibly],
                  setters: false,
                )
              end
            end
          end
        end
      end

      # a module of accessors for described property names of the given schema.
      # getters are always defined. setters are defined by default.
      #
      # @api private
      # @param schema [JSI::Schema] a schema for which to define accessors for any described property names
      # @param conflicting_modules [Enumerable<Module>] an array of modules (or classes) which
      #   may be used alongside the accessor module. methods defined by any conflicting_module
      #   will not be defined as accessors.
      # @param setters [Boolean] whether to define setter methods
      # @return [Module]
      def accessor_module_for_schema(schema, conflicting_modules: , setters: true)
        Schema.ensure_schema(schema)
        jsi_memoize(:accessor_module_for_schema, schema: schema, conflicting_modules: conflicting_modules, setters: setters) do |schema: , conflicting_modules: , setters: |
          Module.new do
            begin
              define_singleton_method(:inspect) { '(JSI Schema Accessor Module)' }

              conflicting_instance_methods = conflicting_modules.map do |mod|
                mod.instance_methods + mod.private_instance_methods
              end.inject(Set.new, &:|)

              accessors_to_define = schema.described_object_property_names.select do |name|
                # must not conflict with any method on a conflicting module
                Util.ok_ruby_method_name?(name) && !conflicting_instance_methods.any? { |mn| mn.to_s == name }
              end.to_set.freeze

              define_singleton_method(:jsi_property_accessors) { accessors_to_define }

              accessors_to_define.each do |property_name|
                define_method(property_name) do |**kw|
                  self[property_name, **kw]
                end
                if setters
                  define_method("#{property_name}=") do |value|
                    self[property_name] = value
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # a JSI Schema module and a JSI::NotASchemaModule are both a SchemaModulePossibly.
  # this module provides a #[] method.
  module SchemaModulePossibly
    attr_reader :possibly_schema_node

    # a name relative to a named schema module of an ancestor schema.
    # for example, if `Foos = JSI::JSONSchemaOrgDraft07.new_schema_module({'items' => {}})`
    # then the module `Foos.items` will have a name_from_ancestor of `"Foos.items"`
    # @api private
    # @return [String, nil]
    def name_from_ancestor
      named_ancestor_schema, tokens = named_ancestor_schema_tokens
      return nil unless named_ancestor_schema

      name = named_ancestor_schema.jsi_schema_module.name
      ancestor = named_ancestor_schema
      tokens.each do |token|
        if ancestor.jsi_schemas.any? { |s| s.jsi_schema_module.jsi_property_accessors.include?(token) }
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

    # subscripting a JSI schema module or a NotASchemaModule will subscript the node, and
    # if the result is a JSI::Schema, return the JSI Schema module of that schema; if it is a JSI::Base,
    # return a NotASchemaModule; or if it is another value (a basic type), return that value.
    #
    # @param token [Object]
    # @return [Module, NotASchemaModule, Object]
    def [](token, **kw)
      raise(ArgumentError) unless kw.empty? # TODO remove eventually (keyword argument compatibility)
      sub = @possibly_schema_node[token]
      if sub.is_a?(JSI::Schema)
        sub.jsi_schema_module
      elsif sub.is_a?(JSI::Base)
        NotASchemaModule.new(sub)
      else
        sub
      end
    end

    private

    # @return [Array<JSI::Schema, Array>, nil]
    def named_ancestor_schema_tokens
      schema_ancestors = possibly_schema_node.jsi_ancestor_nodes
      named_ancestor_schema = schema_ancestors.detect { |jsi| jsi.is_a?(JSI::Schema) && jsi.jsi_schema_module.name }
      return nil unless named_ancestor_schema
      tokens = possibly_schema_node.jsi_ptr.relative_to(named_ancestor_schema.jsi_ptr).tokens
      [named_ancestor_schema, tokens]
    end
  end

  # a JSI Schema Module is a module which represents a schema. a NotASchemaModule represents
  # a node in a schema's document which is not a schema, such as the 'properties'
  # object (which contains schemas but is not a schema).
  #
  # instances of this class act as a stand-in to allow users to subscript or call property accessors on
  # schema modules to refer to their subschemas' schema modules.
  #
  # a NotASchemaModule is extended with the module_for_schema of the node's schema.
  #
  # NotASchemaModule holds a node which is not a schema. when subscripted, it subscripts
  # its node. if the value is a JSI::Schema, its schema module is returned. if the value
  # is another node, a NotASchemaModule for that node is returned. otherwise - when the
  # value is a basic type - that value itself is returned.
  class NotASchemaModule
    # @param node [JSI::Base]
    def initialize(node)
      raise(Bug, "node must be JSI::Base: #{node.pretty_inspect.chomp}") unless node.is_a?(JSI::Base)
      raise(Bug, "node must not be JSI::Schema: #{node.pretty_inspect.chomp}") if node.is_a?(JSI::Schema)
      @possibly_schema_node = node
      node.jsi_schemas.each do |schema|
        extend(JSI::SchemaClasses.accessor_module_for_schema(schema, conflicting_modules: [NotASchemaModule, SchemaModulePossibly], setters: false))
      end
    end

    include SchemaModulePossibly

    # @return [String]
    def inspect
      if name_from_ancestor
        "#{name_from_ancestor} (JSI wrapper for Schema Module)"
      else
        "(JSI wrapper for Schema Module: #{@possibly_schema_node.jsi_ptr.uri})"
      end
    end

    alias_method :to_s, :inspect
  end
end
