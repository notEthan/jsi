# frozen_string_literal: true

module JSI
  # JSI Schema Modules are extended with JSI::SchemaModule
  module SchemaModule
    # @return [String] absolute schema_id of the schema this module represents.
    #   see {Schema#schema_id}.
    def schema_id
      schema.schema_id
    end

    # @return [String]
    def inspect
      uri = schema.schema_id || schema.jsi_ptr.uri
      if name
        "#{name} (#{uri})"
      else
        "(JSI Schema Module: #{uri})"
      end
    end

    # invokes {JSI::Schema#new_jsi} on this module's schema, passing the given instance.
    # @return [JSI::Base] a JSI whose instance is the given instance
    def new_jsi(instance, *a, &b)
      schema.new_jsi(instance, *a, &b)
    end
  end

  # a module to extend the JSI Schema Module of a schema which describes other schemas
  module DescribesSchemaModule
    # instantiates the given schema content as a JSI Schema.
    #
    # @param schema_content [#to_hash, Boolean] an object to be instantiated as a schema
    # @return [JSI::Base, JSI::Schema] a JSI whose instance is the given schema_content and whose schemas
    #   consist of this module's schema.
    def new_schema(schema_content, *a)
      schema.new_schema(schema_content, *a)
    end
  end

  # this module is a namespace for building schema classes and schema modules.
  module SchemaClasses
    extend Util::Memoize

    class << self
      # see {JSI.class_for_schemas}
      def class_for_schemas(schema_objects)
        schemas = SchemaSet.new(schema_objects) { |schema_object| JSI.new_schema(schema_object) }

        jsi_memoize(:class_for_schemas, schemas) do |schemas|
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
      # @param modules [Set<Module>] metaschema instance modules
      # @return [Class] a subclass of MetaschemaNode::BootstrapSchema with the given modules included
      def bootstrap_schema_class(modules)
        modules = Util.ensure_module_set(modules)
        jsi_memoize(__method__, modules) do |modules|
          Class.new(MetaschemaNode::BootstrapSchema).instance_exec(modules) do |modules|
            define_singleton_method(:metaschema_instance_modules) { modules }
            define_method(:metaschema_instance_modules) { modules }
            modules.each { |mod| include(mod) }

            self
          end
        end
      end

      # a module for the given schema, with accessor methods for any object property names the schema
      # identifies (see {JSI::Schema#described_object_property_names}).
      #
      # defines a singleton method #schema to access the {JSI::Schema} this module represents, and extends
      # the module with {JSI::SchemaModule}.
      def module_for_schema(schema)
        Schema.ensure_schema(schema)
        jsi_memoize(:module_for_schema, schema) do |schema|
          Module.new.tap do |m|
            m.module_eval do
              define_singleton_method(:schema) { schema }

              extend SchemaModule

              schema.jsi_schema_instance_modules.each do |mod|
                include(mod)
              end

              include JSI::SchemaClasses.accessor_module_for_schema(schema,
                conflicting_modules: Set[JSI::Base, JSI::PathedArrayNode, JSI::PathedHashNode] +
                  schema.jsi_schema_instance_modules,
              )

              if schema.describes_schema?
                extend DescribesSchemaModule
              end

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

      # @param schema [JSI::Schema] a schema for which to define accessors for any described property names
      # @param conflicting_modules [Enumerable<Module>] an array of modules (or classes) which
      #   may be used alongside the accessor module. methods defined by any conflicting_module
      #   will not be defined as accessors.
      # @return [Module] a module of accessors (setters and getters) for described property names of the given
      #   schema
      def accessor_module_for_schema(schema, conflicting_modules: , setters: true)
        Schema.ensure_schema(schema)
        jsi_memoize(:accessor_module_for_schema, schema, conflicting_modules, setters) do |schema, conflicting_modules, setters|
          Module.new.tap do |m|
            m.module_eval do
              conflicting_instance_methods = (conflicting_modules + [m]).map do |mod|
                mod.instance_methods + mod.private_instance_methods
              end.inject(Set.new, &:|)

              accessors_to_define = schema.described_object_property_names.select do |name|
                do_define = true
                # must be a string
                do_define &&= name.respond_to?(:to_str)
                # must not conflict with any method on a conflicting module
                do_define &&= !conflicting_instance_methods.any? { |m| m.to_s == name }

                do_define
              end

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

    # subscripting a JSI schema module or a NotASchemaModule will subscript the node, and
    # if the result is a JSI::Schema, return the JSI Schema module of that schema; if it is a PathedNode,
    # return a NotASchemaModule; or if it is another value (a basic type), return that value.
    #
    # @param token [Object]
    # @return [Class, NotASchemaModule, Object]
    def [](token)
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

  # a schema module is a module which represents a schema. a NotASchemaModule represents
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
  end
end
