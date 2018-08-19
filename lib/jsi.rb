require "jsi/version"
require "pp"
require "jsi/json-schema-fragments"
require "jsi/util"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  class Bug < NotImplementedError
  end

  autoload :JSON, 'jsi/json'
  autoload :Typelike, 'jsi/typelike_modules'
  autoload :Hashlike, 'jsi/typelike_modules'
  autoload :Arraylike, 'jsi/typelike_modules'
  autoload :Schema, 'jsi/schema'
  autoload :SchemaInstanceBase, 'jsi/schema_instance_base'
  autoload :SchemaInstanceBaseArray, 'jsi/schema_instance_base'
  autoload :SchemaInstanceBaseHash, 'jsi/schema_instance_base'
  autoload :SchemaClasses, 'jsi/schema_instance_base'
  autoload :ObjectJSONCoder, 'jsi/schema_instance_json_coder'
  autoload :StructJSONCoder, 'jsi/struct_json_coder'
  autoload :SchemaInstanceJSONCoder,'jsi/schema_instance_json_coder'

  def self.class_for_schema(*a, &b)
    SchemaClasses.class_for_schema(*a, &b)
  end
end
