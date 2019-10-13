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
  end

  # this module is just a namespace for schema classes.
  module SchemaClasses
    # JSI::SchemaClasses[schema_id] returns a class for the schema with the
    # given id, the same class as returned from JSI.class_for_schema.
    #
    # @param schema_id [String] absolute schema id as returned by {JSI::Schema#schema_id}
    # @return [Class subclassing JSI::Base] the class for that schema
    def self.[](schema_id)
      @classes_by_id[schema_id]
    end
    @classes_by_id = {}

    class << self
      include Memoize

      # see {JSI.class_for_schema}
      def class_for_schema(schema_object)
        memoize(:class_for_schema, JSI::Schema.from_object(schema_object)) do |schema_|
          Class.new(Base).instance_exec(schema_) do |schema|
            define_singleton_method(:schema) { schema }
            define_method(:schema) { schema }
            include(schema.jsi_schema_module)

            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            if schema.schema_id
              SchemaClasses.instance_exec { @classes_by_id }[schema.schema_id] = self
            end

            self
          end
        end
      end

      # a module for the given schema, with accessor methods for any object property names the schema
      # identifies (see {JSI::Schema#described_object_property_names}).
      #
      # defines a singleton method #schema to access the {JSI::Schema} this module represents, and extends
      # the module with {JSI::SchemaModule}.
      #
      # no property names that are the same as existing method names on given conflicting_modules will
      # be defined. callers should use #[] and #[]= to access properties whose names conflict with such
      # methods.
      def SchemaClasses.module_for_schema(schema_object, conflicting_modules: [])
        schema__ = JSI::Schema.from_object(schema_object)
        memoize(:module_for_schema, schema__, conflicting_modules) do |schema_, conflicting_modules_|
          Module.new.tap do |m|
            m.instance_exec(schema_) do |schema|
              define_singleton_method(:schema) { schema }
              extend SchemaModule

              conflicting_instance_methods = (conflicting_modules_ + [m]).map do |mod|
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
end
