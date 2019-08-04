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
  autoload :Base, 'jsi/base'
  autoload :BaseArray, 'jsi/base'
  autoload :BaseHash, 'jsi/base'
  autoload :SchemaClasses, 'jsi/base'
  autoload :ObjectJSONCoder, 'jsi/schema_instance_json_coder'
  autoload :SchemaInstanceJSONCoder, 'jsi/schema_instance_json_coder'

  # @return [Class subclassing JSI::Base] a JSI class which represents the
  #   given schema. instances of the class represent JSON Schema instances
  #   for the given schema.
  def self.class_for_schema(*a, &b)
    SchemaClasses.class_for_schema(*a, &b)
  end
end
