# frozen_string_literal: true

require "jsi/version"
require "pp"
require "set"
require "pathname"
require "jsi/json-schema-fragments"
require "jsi/util"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  class Bug < NotImplementedError
  end

  ROOT_PATH = Pathname.new(__FILE__).dirname.parent.expand_path
  RESOURCES_PATH = ROOT_PATH.join('resources')

  autoload :JSON, 'jsi/json'
  autoload :PathedNode, 'jsi/pathed_node'
  autoload :Typelike, 'jsi/typelike_modules'
  autoload :Hashlike, 'jsi/typelike_modules'
  autoload :Arraylike, 'jsi/typelike_modules'
  autoload :Schema, 'jsi/schema'
  autoload :Base, 'jsi/base'
  autoload :Metaschema, 'jsi/metaschema'
  autoload :MetaschemaNode, 'jsi/metaschema_node'
  autoload :SchemaClasses, 'jsi/schema_classes'
  autoload :JSICoder, 'jsi/jsi_coder'

  autoload :JSONSchemaOrgDraft04, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft06, 'schemas/json-schema.org/draft-06/schema'

  autoload :SimpleWrap, 'jsi/simple_wrap'

  # @param schemas [Enumerable<JSI::Schema, #to_hash, Boolean>] schemas to represent with the class
  # @return [Class subclassing JSI::Base] a JSI class which represents the given schemas.
  #   an instance of the class represents a JSON Schema instance described by all of the given schemas.
  def self.class_for_schemas(*schemas)
    SchemaClasses.class_for_schemas(*schemas)
  end
end
