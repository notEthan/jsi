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

    # invokes {JSI::Schema#new_jsi} on this module's schema, passing the given instance.
    #
    # @param (see JSI::Schema#new_jsi)
    # @return [JSI::Base] a JSI whose instance is the given instance
    def new_jsi(instance, **kw, &b)
      schema.new_jsi(instance, **kw, &b)
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
  end

  # this module is a namespace for building schema classes and schema modules.
  module SchemaClasses
    extend Util::Memoize

    class << self
      # a JSI Schema Class which represents the given schemas.
      # an instance of the class is a JSON Schema instance described by all of the given schemas.
      # @private
      # @param schemas [Enumerable<JSI::Schema>] schemas which the class will represent
      # @return [Class subclassing JSI::Base]
      def class_for_schemas(schemas)
        schemas = SchemaSet.ensure_schema_set(schemas)

        jsi_memoize(:class_for_schemas, schemas: schemas) do |schemas: |
          Class.new(Base).instance_exec(schemas) do |schemas|
            define_singleton_method(:jsi_class_schemas) { schemas }
            define_method(:jsi_schemas) { schemas }
            schemas.each { |schema| include(schema.jsi_schema_module) }
            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            self
          end
        end
      end

      # @private
      # a subclass of MetaschemaNode::BootstrapSchema with the given modules included
      # @param modules [Set<Module>] metaschema instance modules
      # @return [Class]
      def bootstrap_schema_class(modules)
        modules = Util.ensure_module_set(modules)
        jsi_memoize(__method__, modules: modules) do |modules: |
          Class.new(MetaschemaNode::BootstrapSchema).instance_exec(modules) do |modules|
            define_singleton_method(:metaschema_instance_modules) { modules }
            define_method(:metaschema_instance_modules) { modules }
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
          Module.new.tap do |m|
            m.module_eval do
              define_singleton_method(:schema) { schema }

              extend SchemaModule

              schema.jsi_schema_instance_modules.each do |mod|
                include(mod)
              end

              accessor_module = JSI::SchemaClasses.accessor_module_for_schema(schema,
                conflicting_modules: Set[JSI::Base, JSI::PathedArrayNode, JSI::PathedHashNode] +
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
      # @param schema [JSI::Schema] a schema for which to define accessors for any described property names
      # @param conflicting_modules [Enumerable<Module>] an array of modules (or classes) which
      #   may be used alongside the accessor module. methods defined by any conflicting_module
      #   will not be defined as accessors.
      # @param setters [Boolean] whether to define setter methods
      # @return [Module]
      def accessor_module_for_schema(schema, conflicting_modules: , setters: true)
        Schema.ensure_schema(schema)
        jsi_memoize(:accessor_module_for_schema, schema: schema, conflicting_modules: conflicting_modules, setters: setters) do |schema: , conflicting_modules: , setters: |
          Module.new.tap do |m|
            m.module_eval do
              conflicting_instance_methods = (conflicting_modules + [m]).map do |mod|
                mod.instance_methods + mod.private_instance_methods
              end.inject(Set.new, &:|)

              accessors_to_define = schema.described_object_property_names.select do |name|
                # must not conflict with any method on a conflicting module
                Util.ok_ruby_method_name?(name) && !conflicting_instance_methods.any? { |mn| mn.to_s == name }
              end.to_set.freeze

              define_singleton_method(:jsi_property_accessors) { accessors_to_define }

              accessors_to_define.each do |property_name|
                define_method(property_name) do |*a|
                  self[property_name, *a]
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
    # @return [String, nil]
    def name_from_ancestor
      schema_ancestors = [possibly_schema_node] + possibly_schema_node.jsi_parent_nodes
      named_parent_schema = schema_ancestors.detect { |jsi| jsi.is_a?(JSI::Schema) && jsi.jsi_schema_module.name }

      return nil unless named_parent_schema

      tokens = possibly_schema_node.jsi_ptr.ptr_relative_to(named_parent_schema.jsi_ptr).tokens
      name = named_parent_schema.jsi_schema_module.name
      parent = named_parent_schema
      tokens.each do |token|
        if parent.jsi_schemas.any? { |s| s.jsi_schema_module.jsi_property_accessors.include?(token) }
          name += ".#{token}"
        elsif [String, Numeric, TrueClass, FalseClass, NilClass].any? { |m| token.is_a?(m) }
          name += "[#{token.inspect}]"
        else
          return nil
        end
        parent = parent[token]
      end
      name
    end

    # subscripting a JSI schema module or a NotASchemaModule will subscript the node, and
    # if the result is a JSI::Schema, return the JSI Schema module of that schema; if it is a PathedNode,
    # return a NotASchemaModule; or if it is another value (a basic type), return that value.
    #
    # @param token [Object]
    # @return [Module, NotASchemaModule, Object]
    def [](token, **kw)
      raise(ArgumentError) unless kw.empty? # TODO remove eventually (keyword argument compatibility)
      sub = @possibly_schema_node[token]
      if sub.is_a?(JSI::Schema)
        sub.jsi_schema_module
      elsif sub.is_a?(JSI::PathedNode)
        NotASchemaModule.new(sub)
      else
        sub
      end
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
    # @param node [JSI::PathedNode]
    def initialize(node)
      unless node.is_a?(JSI::PathedNode)
        raise(TypeError, "not JSI::PathedNode: #{node.pretty_inspect.chomp}")
      end
      if node.is_a?(JSI::Schema)
        raise(TypeError, "cannot instantiate NotASchemaModule for a JSI::Schema node: #{node.pretty_inspect.chomp}")
      end
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
  end
end
