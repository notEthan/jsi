# frozen_string_literal: true

module JSI
  metaschema_document = Util.json_parse_freeze(SCHEMAS_PATH.join('json-schema.org/draft-04/schema.json').read)
  JSONSchemaDraft04 = JSI.new_metaschema_module(metaschema_document,
    dialect: JSI::Schema::Draft04::DIALECT,
  )

  # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
  # properties/additionalProperties and properties/additionalItems.
  # these still describe schemas, despite not being described by the meta-schema.
  JSONSchemaDraft04.properties["additionalProperties"].anyOf[0].describes_schema!(JSI::Schema::Draft04::DIALECT)
  JSONSchemaDraft04.properties["additionalItems"].anyOf[0].describes_schema!(JSI::Schema::Draft04::DIALECT)

  # the JSI schema module for `http://json-schema.org/draft-04/schema`
  module JSONSchemaDraft04
    # @!parse extend JSI::SchemaModule::MetaSchemaModule
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

    module Id
    end
    module Xschema
    end
    module Title
    end
    module Description
    end
    module Default
    end
    module MultipleOf
    end
    module Maximum
    end
    module ExclusiveMaximum
    end
    module Minimum
    end
    module ExclusiveMinimum
    end
    module MaxLength
    end
    module MinLength
    end
    module Pattern
    end
    module AdditionalItems
    end
    module Items
    end
    module MaxItems
    end
    module MinItems
    end
    module UniqueItems
    end
    module MaxProperties
    end
    module MinProperties
    end
    module Required
    end
    module AdditionalProperties
    end
    module Definitions
    end
    module Properties
    end
    module PatternProperties
    end
    module Dependencies
    end
    module Enum
    end
    module Type
    end
    module Format
    end
    module AllOf
    end
    module AnyOf
    end
    module OneOf
    end
    module Not
    end

    module SchemaArray
    end
    module PositiveInteger
    end
    module PositiveIntegerDefault0
    end
    module SimpleType
    end
    module StringArray
    end

    AdditionalItems::Boolean = AdditionalItems.anyOf[0]
    AdditionalProperties::Boolean = AdditionalProperties.anyOf[0]
    Dependencies::Dependency = Dependencies.additionalProperties
    Type::Array = Type.anyOf[1]
    PositiveIntegerDefault0::Default0 = PositiveIntegerDefault0.allOf[1]
    StringItem = StringArray.items

    module AdditionalItems::Boolean
    end
    module AdditionalProperties::Boolean
    end
    module Dependencies::Dependency
    end
    module Type::Array
    end
    module PositiveIntegerDefault0::Default0
    end
    module StringItem
    end
  end
end
