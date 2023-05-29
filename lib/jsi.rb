# frozen_string_literal: true

require "jsi/version"
require "pp"
require "set"
require "json"
require "pathname"
require "bigdecimal"
require "addressable/uri"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  #
  # if you've found this class because JSI has raised this error, please open an issue with the backtrace
  # and any context you can provide at https://github.com/notEthan/jsi/issues
  class Bug < NotImplementedError
  end

  # @private TODO remove, any ruby without this is already long EOL
  FrozenError = Object.const_defined?(:FrozenError) ? ::FrozenError : Class.new(StandardError)

  # @private
  ROOT_PATH = Pathname.new(__FILE__).dirname.parent.expand_path

  # @private
  RESOURCES_PATH = ROOT_PATH.join('{resources}')

  # @private
  SCHEMAS_PATH = RESOURCES_PATH.join('schemas')

  autoload :Util, 'jsi/util'
  autoload :Ptr, 'jsi/ptr'
  autoload :Schema, 'jsi/schema'
  autoload :SchemaSet, 'jsi/schema_set'
  autoload :Base, 'jsi/base'
  autoload :Metaschema, 'jsi/metaschema'
  autoload :MetaschemaNode, 'jsi/metaschema_node'
  autoload :SchemaModule, 'jsi/schema_classes'
  autoload :SchemaClasses, 'jsi/schema_classes'
  autoload :SchemaRegistry, 'jsi/schema_registry'
  autoload :Validation, 'jsi/validation'
  autoload :JSICoder, 'jsi/jsi_coder'

  autoload :JSONSchemaOrgDraft04, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft06, 'schemas/json-schema.org/draft-06/schema'
  autoload :JSONSchemaOrgDraft07, 'schemas/json-schema.org/draft-07/schema'

  autoload :SimpleWrap, 'jsi/simple_wrap'

  # (see JSI::Schema.new_schema)
  def self.new_schema(schema_content,
      # params of Schema.new_schema have their default values repeated here. delegating in a splat
      # would remove repetition, but yard doesn't display delegated defaults with its (see X) directive.
      default_metaschema: nil,
      uri: nil,
      stringify_symbol_keys: true
  )
    JSI::Schema.new_schema(schema_content,
      default_metaschema: default_metaschema,
      uri: uri,
      stringify_symbol_keys: stringify_symbol_keys,
    )
  end

  # Instantiates the given schema content as a JSI Schema, passing all params to
  # {JSI.new_schema}, and returns its {Schema#jsi_schema_module JSI Schema Module}.
  #
  # @return [Module + JSI::SchemaModule]
  def self.new_schema_module(schema_content, **kw)
    JSI::Schema.new_schema(schema_content, **kw).jsi_schema_module
  end

  # `JSI.schema_registry` is the {JSI::SchemaRegistry} in which schemas are registered.
  #
  # @return [JSI::SchemaRegistry]
  def self.schema_registry
    @schema_registry
  end

  # @param schema_registry [JSI::SchemaRegistry]
  def self.schema_registry=(schema_registry)
    @schema_registry = schema_registry
  end

  DEFAULT_SCHEMA_REGISTRY = SchemaRegistry.new.tap do |schema_registry|
    schema_registry.autoload_uri("http://json-schema.org/draft-04/schema") { JSI::JSONSchemaOrgDraft04.schema }
    schema_registry.autoload_uri("http://json-schema.org/draft-06/schema") { JSI::JSONSchemaOrgDraft06.schema }
    schema_registry.autoload_uri("http://json-schema.org/draft-07/schema") { JSI::JSONSchemaOrgDraft07.schema }
  end.freeze

  self.schema_registry = DEFAULT_SCHEMA_REGISTRY.dup
end
