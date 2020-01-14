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
      %Q(#<Module for Schema: #{schema_id}>)
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
            include(JSI::SchemaClasses.module_for_schema(schema, conflicting_modules: [Base, BaseArray, BaseHash]))

            jsi_class = self
            define_method(:jsi_class) { jsi_class }

            SchemaClasses.instance_exec(self) { |klass| @classes_by_id[klass.schema_id] = klass }

            self
          end
        end
      end

      # a module for the given schema, with accessor methods for any object
      # property names the schema identifies. also has a singleton method
      # called #schema to access the {JSI::Schema} this module represents.
      #
      # accessor methods are defined on these modules so that methods can be
      # defined on {JSI.class_for_schema} classes without method redefinition
      # warnings. additionally, these overriding instance methods can call
      # `super` to invoke the normal accessor behavior.
      #
      # no property names that are the same as existing method names on the JSI
      # class will be defined. users should use #[] and #[]= to access properties
      # whose names conflict with existing methods.
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
                  if respond_to?(:[])
                    self[property_name]
                  else
                    raise(NoMethodError, "schema instance of class #{self.class} does not respond to []; cannot call reader '#{property_name}'. instance is #{instance.pretty_inspect.chomp}")
                  end
                end
                define_method("#{property_name}=") do |value|
                  if respond_to?(:[]=)
                    self[property_name] = value
                  else
                    raise(NoMethodError, "schema instance of class #{self.class} does not respond to []=; cannot call writer '#{property_name}='. instance is #{instance.pretty_inspect.chomp}")
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
