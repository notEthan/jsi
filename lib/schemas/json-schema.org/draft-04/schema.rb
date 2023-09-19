# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-04/schema.json').read)
  JSONSchemaOrgDraft04 = JSI.new_metaschema_module(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft04],
  )

  # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
  # properties/additionalProperties and properties/additionalItems.
  # these still describe schemas, despite not being described by the metaschema.
  also_describe_schemas =
    JSONSchemaOrgDraft04.schema["properties"]["additionalProperties"]["anyOf"] +
    JSONSchemaOrgDraft04.schema["properties"]["additionalItems"]["anyOf"]
  also_describe_schemas.each do |schema|
    schema.describes_schema!([JSI::Schema::Draft04])
  end

  # the JSI schema module for `http://json-schema.org/draft-04/schema`
  module JSONSchemaOrgDraft04
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft04


    Id        = properties['id']
    Xschema    = properties['$schema']
    Title       = properties['title']
    Description  = properties['description']
    Default       = properties['default']
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
    MaxItems       = properties['maxItems']
    MinItems        = properties['minItems']
    UniqueItems      = properties['uniqueItems']
    MaxProperties     = properties['maxProperties']
    MinProperties      = properties['minProperties']
    Required            = properties['required']
    AdditionalProperties = properties['additionalProperties']
    Definitions         = properties['definitions']
    Properties         = properties['properties']
    PatternProperties = properties['patternProperties']
    Dependencies     = properties['dependencies']
    Enum            = properties['enum']
    Type           = properties['type']
    Format        = properties['format']
    AllOf        = properties['allOf']
    AnyOf       = properties['anyOf']
    OneOf      = properties['oneOf']
    Not       = properties['not']

    SchemaArray           = definitions['schemaArray']
    PositiveInteger        = definitions['positiveInteger']
    PositiveIntegerDefault0 = definitions['positiveIntegerDefault0']
    SimpleType             = definitions['simpleTypes']
    StringArray           = definitions['stringArray']

    AdditionalItems::Boolean = AdditionalItems.anyOf[0]
    AdditionalProperties::Boolean = AdditionalProperties.anyOf[0]
    Dependencies::Dependency = Dependencies.additionalProperties
    Type::Array = Type.anyOf[1]
    PositiveIntegerDefault0::Default0 = PositiveIntegerDefault0.allOf[1]
    StringItem = StringArray.items
  end
end
