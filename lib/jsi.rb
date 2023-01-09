# frozen_string_literal: true

require "jsi/version"
require "pp"
require "set"
require "json"
require "pathname"
require "bigdecimal"
require "addressable/uri"

require "jsi/util"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  #
  # if you've found this class because JSI has raised this error, please open an issue with the backtrace
  # and any context you can provide at https://github.com/notEthan/jsi/issues
  class Bug < NotImplementedError
  end

  # @private
  ROOT_PATH = Pathname.new(__FILE__).dirname.parent.expand_path

  # @private
  RESOURCES_PATH = ROOT_PATH.join('{resources}')

  # @private
  SCHEMAS_PATH = RESOURCES_PATH.join('schemas')

  autoload :Ptr, 'jsi/ptr'
  autoload :Typelike, 'jsi/util/typelike'
  autoload :Schema, 'jsi/schema'
  autoload :SchemaSet, 'jsi/schema_set'
  autoload :Base, 'jsi/base'
  autoload :Metaschema, 'jsi/metaschema'
  autoload :MetaschemaNode, 'jsi/metaschema_node'
  autoload :SchemaClasses, 'jsi/schema_classes'
  autoload :SchemaRegistry, 'jsi/schema_registry'
  autoload :Validation, 'jsi/validation'
  autoload :JSICoder, 'jsi/jsi_coder'

  autoload :JSONSchemaOrgDraft04, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft06, 'schemas/json-schema.org/draft-06/schema'
  autoload :JSONSchemaOrgDraft07, 'schemas/json-schema.org/draft-07/schema'

  autoload :SimpleWrap, 'jsi/simple_wrap'

  # instantiates a given schema object as a JSI Schema.
  #
  # see {JSI::Schema.new_schema}
  #
  # @param (see JSI::Schema.new_schema)
  # @return (see JSI::Schema.new_schema)
  def self.new_schema(schema_object, **kw)
    JSI::Schema.new_schema(schema_object, **kw)
  end

  # instantiates a given schema object as a JSI Schema and returns its JSI Schema Module.
  #
  # shortcut to chain {JSI::Schema.new_schema} + {Schema#jsi_schema_module}.
  #
  # @param (see JSI::Schema.new_schema)
  # @return [Module, JSI::SchemaModule] the JSI Schema Module of the schema
  def self.new_schema_module(schema_object, **kw)
    JSI::Schema.new_schema(schema_object, **kw).jsi_schema_module
  end

  # `JSI.schema_registry` is the {JSI::SchemaRegistry} in which schemas are registered.
  #
  # @return [JSI::SchemaRegistry]
  def self.schema_registry
    return @schema_registry if instance_variable_defined?(:@schema_registry)
    @schema_registry = SchemaRegistry.new
  end
end

JSI.schema_registry.autoload_uri("http://json-schema.org/draft-04/schema") { JSI::JSONSchemaOrgDraft04.schema }
JSI.schema_registry.autoload_uri("http://json-schema.org/draft-06/schema") { JSI::JSONSchemaOrgDraft06.schema }
JSI.schema_registry.autoload_uri("http://json-schema.org/draft-07/schema") { JSI::JSONSchemaOrgDraft07.schema }
