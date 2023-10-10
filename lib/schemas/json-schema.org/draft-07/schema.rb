# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-07/schema.json').read)
  JSONSchemaOrgDraft07 = JSI.new_metaschema_module(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft07],
  )

  # the JSI schema module for `http://json-schema.org/draft-07/schema`
  module JSONSchemaOrgDraft07
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft07


    Id     = properties['$id']
    Xschema = properties['$schema']
    Ref      = properties['$ref']
    Comment   = properties['$comment']
    Title      = properties['title']
    Description = properties['description']
    Default     = properties['default']
    ReadOnly     = properties['readOnly']
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
    Type           = properties['type']
    Format          = properties['format']
    ContentMediaType = properties['contentMediaType']
    ContentEncoding = properties['contentEncoding']
    If             = properties['if']
    Then          = properties['then']
    Else         = properties['else']
    AllOf       = properties['allOf']
    AnyOf      = properties['anyOf']
    OneOf     = properties['oneOf']
    Not      = properties['not']

    SchemaArray              = definitions['schemaArray']
    NonNegativeInteger        = definitions['nonNegativeInteger']
    NonNegativeIntegerDefault0 = definitions['nonNegativeIntegerDefault0']
    SimpleType                = definitions['simpleTypes']
    StringArray              = definitions['stringArray']

    module Id
    end
    module Xschema
    end
    module Ref
    end
    module Comment
    end
    module Title
    end
    module Description
    end
    module Default
    end
    module ReadOnly
    end
    module Examples
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
    module Contains
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
    module PropertyNames
    end
    module Const
    end
    module Enum
    end
    module Type
    end
    module Format
    end
    module ContentMediaType
    end
    module ContentEncoding
    end
    module If
    end
    module Then
    end
    module Else
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
    module NonNegativeInteger
    end
    module NonNegativeIntegerDefault0
    end
    module SimpleType
    end
    module StringArray
    end

    Example = Examples.items
    PatternPropertyPattern = PatternProperties.propertyNames
    Dependencies::Dependency = Dependencies.additionalProperties
    Enum::Item = Enum.items
    Type::Array = Type.anyOf[1]
    NonNegativeIntegerDefault0::Default0 = NonNegativeIntegerDefault0.allOf[1]
    StringItem = StringArray.items

    module Example
    end
    module PatternPropertyPattern
    end
    module Dependencies::Dependency
    end
    module Enum::Item
    end
    module Type::Array
    end
    module NonNegativeIntegerDefault0::Default0
    end
    module StringItem
    end
  end
end
