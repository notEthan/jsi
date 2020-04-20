# frozen_string_literal: true

module JSI
  class Metaschema < JSI::Base
    include JSI::Schema

    # @param instance [Hash]
    # @param jsi_schema_module_modules [Set]
    def initialize(instance, jsi_schema_instance_modules: , jsi_schema_module_modules: Set[], **options)
      self.jsi_schema_instance_modules = jsi_schema_instance_modules
      self.jsi_schema_module_modules = jsi_schema_module_modules

      # this schema is an instance of itself, so the schema instance modules included for its instances
      # also extend itself
      jsi_schema_instance_modules.each do |mod|
        extend(mod)
      end
      super(instance, options)
      # since our jsi_schemas is just this metaschema itself, we extend ourselves with our own
      # schema module
      extend(self.jsi_schema_module)
    end

    # @return [Set<JSI::Schema>] returns one schema, this metaschema itself
    def jsi_schemas
      Set[self]
    end

    # @private
    def jsi_fingerprint
      {
        class: JSI::Base, 
        jsi_document: jsi_document,
        jsi_ptr: jsi_ptr,
        # is_metaschema + instance modules in Metaschema take the place of jsi_schemas in Base
        jsi_is_metaschema: true,
        jsi_schema_instance_modules: jsi_schema_instance_modules,
      }
    end
  end
end
