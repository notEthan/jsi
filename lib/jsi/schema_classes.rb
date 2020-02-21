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
      idfrag = schema.schema_id || schema.node_ptr.fragment
      if name
        "#{name} (#{idfrag})"
      else
        "(JSI Schema Module: #{idfrag})"
      end
    end

    # invokes {JSI::Schema#new_jsi} on this module's schema, passing the given instance.
    # @return [JSI::Base] a JSI whose instance is the given instance
    def new_jsi(instance, *a, &b)
      schema.new_jsi(instance, *a, &b)
    end
  end

  # this module is just a namespace for schema classes.
  module SchemaClasses
    class << self
      include Util::Memoize

      # see {JSI.class_for_schema}
      def class_for_schema(schema_object)
        jsi_memoize(:class_for_schema, JSI::Schema.from_object(schema_object)) do |schema|
          Class.new(Base).instance_exec(schema) do |schema|
            define_singleton_method(:schema) { schema }
            define_method(:schema) { schema }
            include(schema.jsi_schema_module)

            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            self
          end
        end
      end

      # a module for the given schema, with accessor methods for any object property names the schema
      # identifies (see {JSI::Schema#described_object_property_names}).
      #
      # defines a singleton method #schema to access the {JSI::Schema} this module represents, and extends
      # the module with {JSI::SchemaModule}.
      def module_for_schema(schema_object)
        schema = JSI::Schema.from_object(schema_object)
        jsi_memoize(:module_for_schema, schema) do |schema|
          Module.new.tap do |m|
            m.module_eval do
              define_singleton_method(:schema) { schema }

              extend SchemaModule

              include JSI::SchemaClasses.accessor_module_for_schema(schema, conflicting_modules: [JSI::Base, JSI::BaseArray, JSI::BaseHash])

              @possibly_schema_node = schema
              extend(SchemaModulePossibly)
              extend(JSI::SchemaClasses.accessor_module_for_schema(schema.schema, conflicting_modules: [Module, SchemaModule, SchemaModulePossibly]))
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
      def accessor_module_for_schema(schema, conflicting_modules: )
        jsi_memoize(:accessor_module_for_schema, schema, conflicting_modules) do |schema, conflicting_modules|
          Module.new.tap do |m|
            m.module_eval do
              conflicting_instance_methods = (conflicting_modules + [m]).map do |mod|
                mod.instance_methods + mod.private_instance_methods
              end.inject(Set.new, &:|)
              accessors_to_define = schema.described_object_property_names.map(&:to_s) - conflicting_instance_methods.map(&:to_s)
              accessors_to_define.each do |property_name|
                define_method(property_name) do
                  self[property_name]
                end
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

  # a JSI::Schema module and a JSI::NotASchemaModule are both a SchemaModulePossibly.
  # this module provides a #[] method.
  module SchemaModulePossibly
    attr_reader :possibly_schema_node

    # subscripting a JSI schema module or a NotASchemaModule will subscript the node, and
    # if the result is a JSI::Schema, return a JSI::Schema class; if it is a PathedNode,
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
  # node (which contains schemas but is not a schema).
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
      extend(JSI::SchemaClasses.accessor_module_for_schema(node.schema, conflicting_modules: [NotASchemaModule, SchemaModulePossibly]))
    end

    include SchemaModulePossibly
  end
end
