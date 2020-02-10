# frozen_string_literal: true

require "jsi/version"
require "pp"
require "set"
require "jsi/json-schema-fragments"
require "jsi/util"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  class Bug < NotImplementedError
  end

  autoload :JSON, 'jsi/json'
  autoload :PathedNode, 'jsi/pathed_node'
  autoload :Typelike, 'jsi/typelike_modules'
  autoload :Hashlike, 'jsi/typelike_modules'
  autoload :Arraylike, 'jsi/typelike_modules'
  autoload :Schema, 'jsi/schema'
  autoload :Base, 'jsi/base'
  autoload :BaseArray, 'jsi/base'
  autoload :BaseHash, 'jsi/base'
  autoload :Metaschema, 'jsi/metaschema'
  autoload :MetaschemaNode, 'jsi/metaschema_node'
  autoload :SchemaClasses, 'jsi/schema_classes'
  autoload :JSICoder, 'jsi/jsi_coder'

  autoload :JSONSchemaOrgDraft04Schema, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft04,       'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft06Schema, 'schemas/json-schema.org/draft-06/schema'
  autoload :JSONSchemaOrgDraft06,       'schemas/json-schema.org/draft-06/schema'
  autoload :SimpleWrap, 'jsi/simple_wrap'

  # @return [Class subclassing JSI::Base] a JSI class which represents the
  #   given schema. instances of the class represent JSON Schema instances
  #   for the given schema.
  def self.class_for_schema(*a, &b)
    SchemaClasses.class_for_schema(*a, &b)
  end
end
