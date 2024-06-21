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

  DEFAULT_CONTENT_TO_IMMUTABLE = proc do |content|
    Util.deep_to_frozen(content, not_implemented: proc do |instance|
      raise(ArgumentError, [
        "JSI does not know how to make the given instance immutable.",
        "See new_jsi / new_schema params `mutable` and `to_immutable` documentation for options.",
        "https://www.rubydoc.info/gems/jsi/#{VERSION}/JSI/SchemaSet#new_jsi-instance_method",
        "Given instance: #{instance.pretty_inspect.chomp}",
      ].join("\n"))
    end)
  end

  autoload :Util, 'jsi/util'
  autoload :Ptr, 'jsi/ptr'
  autoload :Schema, 'jsi/schema'
  autoload :SchemaSet, 'jsi/schema_set'
  autoload :Base, 'jsi/base'
  autoload(:MetaSchemaNode, 'jsi/metaschema_node')
  autoload :SchemaModule, 'jsi/schema_classes'
  autoload :SchemaClasses, 'jsi/schema_classes'
  autoload :SchemaRegistry, 'jsi/schema_registry'
  autoload :Validation, 'jsi/validation'
  autoload :JSICoder, 'jsi/jsi_coder'

  autoload :JSONSchemaDraft04, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaDraft06, 'schemas/json-schema.org/draft-06/schema'
  autoload :JSONSchemaDraft07, 'schemas/json-schema.org/draft-07/schema'
  autoload :JSONSchemaOrgDraft04, 'schemas/json-schema.org/draft-04/schema'
  autoload :JSONSchemaOrgDraft06, 'schemas/json-schema.org/draft-06/schema'
  autoload :JSONSchemaOrgDraft07, 'schemas/json-schema.org/draft-07/schema'

  autoload :SimpleWrap, 'jsi/simple_wrap'

  # Instantiates the given schema content as a JSI Schema, passing all params to
  # {JSI.new_schema}, and returns its {Schema#jsi_schema_module JSI Schema Module}.
  #
  # @return (see JSI::Schema::MetaSchema#new_schema_module)
  def self.new_schema_module(schema_content, **kw, &block)
    new_schema(schema_content, **kw, &block).jsi_schema_module
  end

  # @private pending dialect/vocabularies
  # Instantiates the given document as a JSI Meta-Schema.
  #
  # @param metaschema_document an object to be instantiated as a JSI Meta-Schema
  # @param schema_implementation_modules (see MetaSchemaNode#initialize)
  # @param to_immutable (see SchemaSet#new_jsi)
  # @return [JSI::MetaSchemaNode + JSI::Schema::MetaSchema + JSI::Schema]
  def self.new_metaschema(metaschema_document,
      schema_implementation_modules: ,
      to_immutable: DEFAULT_CONTENT_TO_IMMUTABLE
  )
    metaschema_document = to_immutable.call(metaschema_document) if to_immutable

    MetaSchemaNode.new(metaschema_document,
      schema_implementation_modules: schema_implementation_modules,
      jsi_content_to_immutable: to_immutable,
    )
  end

  # @private pending dialect/vocabularies
  # Instantiates the given document as a JSI Meta-Schema, passing all params to
  # {new_metaschema}, and returns its {Schema#jsi_schema_module JSI Schema Module}.
  #
  # @return [JSI::SchemaModule + JSI::SchemaModule::MetaSchemaModule]
  def self.new_metaschema_module(metaschema_document, **kw)
    new_metaschema(metaschema_document, **kw).jsi_schema_module
  end

  # `JSI.schema_registry` is the default {JSI::SchemaRegistry} in which schemas are registered and from
  # which they resolve references.
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
    schema_registry.autoload_uri("http://json-schema.org/draft-04/schema") { JSI::JSONSchemaDraft04.schema }
    schema_registry.autoload_uri("http://json-schema.org/draft-06/schema") { JSI::JSONSchemaDraft06.schema }
    schema_registry.autoload_uri("http://json-schema.org/draft-07/schema") { JSI::JSONSchemaDraft07.schema }
  end.freeze

  self.schema_registry = DEFAULT_SCHEMA_REGISTRY.dup

  Schema # trigger autoload, ensure JSI methods (new_schema etc) defined in schema.rb load
end
