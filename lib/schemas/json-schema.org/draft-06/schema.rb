# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-06/schema.json').read)
  JSONSchemaOrgDraft06 = JSI.new_metaschema_module(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft06],
  )

  # the JSI schema module for `http://json-schema.org/draft-06/schema`
  module JSONSchemaOrgDraft06
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft06


    Id      = properties['$id']
    Xschema  = properties['$schema']
    Ref       = properties['$ref']
    Title      = properties['title']
    Description = properties['description']
    Default      = properties['default']
    Examples      = properties['examples']
    MultipleOf     = properties['multipleOf']
    Maximum         = properties['maximum']
    ExclusiveMaximum = properties['exclusiveMaximum']
    Minimum          = properties['minimum']
    ExclusiveMinimum = properties['exclusiveMinimum']
    MaxLength       = properties['maxLength']
    MinLength      = properties['minLength']
    Pattern        = properties['pattern']
    AdditionalItems = properties['additionalItems']
    Items          = properties['items']
    MaxItems      = properties['maxItems']
    MinItems       = properties['minItems']
    UniqueItems     = properties['uniqueItems']
    Contains         = properties['contains']
    MaxProperties     = properties['maxProperties']
    MinProperties      = properties['minProperties']
    Required            = properties['required']
    AdditionalProperties = properties['additionalProperties']
    Definitions         = properties['definitions']
    Properties         = properties['properties']
    PatternProperties = properties['patternProperties']
    Dependencies     = properties['dependencies']
    PropertyNames   = properties['propertyNames']
    Const          = properties['const']
    Enum          = properties['enum']
    Type         = properties['type']
    Format      = properties['format']
    AllOf      = properties['allOf']
    AnyOf     = properties['anyOf']
    OneOf    = properties['oneOf']
    Not     = properties['not']

    SchemaArray              = definitions['schemaArray']
    NonNegativeInteger        = definitions['nonNegativeInteger']
    NonNegativeIntegerDefault0 = definitions['nonNegativeIntegerDefault0']
    SimpleTypes               = definitions['simpleTypes']
    StringArray              = definitions['stringArray']
  end
end
