# frozen_string_literal: true

=begin
module JSI
  draft201909path = RESOURCES_PATH.join('json-schema.org/draft/2019-09')
  draft201909content = ::JSON.parse(draft201909path.join('schema').read)
  schema_documents = [draft201909content] + draft201909content['allOf'].map do |schema|
    ::JSON.parse(draft201909path.join(schema['$ref']).read)
  end

  schema_documents.each do |doc|
    JSI.schema_registry.register_document(doc['$id'], doc)
  end
  draft201909schema = MetaschemaNode.new(draft201909content,
    root_basic_schema: JSI::BasicSchema::Draft201909.new(JSI::JSON::Pointer[], draft201909content),
    schema_documents: schema_documents
  )
  draft201909schema.jsi_register_schema
  JSONSchemaOrgDraft201909 = draft201909schema.jsi_schema_module
end
=end

=begin
irb -Ilib -rjsi -r active_support -r active_support/core_ext/hash/deep_merge

draft201909path = JSI::RESOURCES_PATH.join('json-schema.org/draft/2019-09')
draft201909content = ::JSON.parse(draft201909path.join('schema').read)
schema_documents = [draft201909content] + draft201909content['allOf'].map do |schema|
  ::JSON.parse(draft201909path.join(schema['$ref']).read)
end

schema_documents.inject({}) { |o, sd| o.deep_merge(sd) }.to_yaml(line_width: -1).pbcopy
=end

require 'yaml'

module JSI
  schema_content = ::YAML.safe_load(RESOURCES_PATH.join('json-schema.org/draft/2019-09/schema-unified.yaml').read)

  JSONSchemaOrgDraft201909 = Metaschema.new(schema_content,
    jsi_schema_instance_modules: Set[JSI::Schema::Draft201909],
    jsi_schema_module_modules: Set[
      Schema::BigMoneyId,
      Schema::BigMoneyAnchor,
      Schema::BigMoneyDefs,
    ],
  ).tap(&:jsi_register_schema).jsi_schema_module

  module JSONSchemaOrgDraft201909
    Definitions = properties['definitions']
    Dependencies = properties['dependencies']
    Id = properties['id']
    Schema = properties['schema']
    Anchor = properties['anchor']
    Ref = properties['ref']
    RecursiveRef = properties['recursiveRef']
    RecursiveAnchor = properties['recursiveAnchor']
    Vocabulary = properties['vocabulary']
    Comment = properties['comment']
    Defs = properties['defs']
    AdditionalItems = properties['additionalItems']
    UnevaluatedItems = properties['unevaluatedItems']
    Items = properties['items']
    Contains = properties['contains']
    AdditionalProperties = properties['additionalProperties']
    UnevaluatedProperties = properties['unevaluatedProperties']
    Properties = properties['properties']
    PatternProperties = properties['patternProperties']
    DependentSchemas = properties['dependentSchemas']
    PropertyNames = properties['propertyNames']
    If = properties['if']
    Then = properties['then']
    Else = properties['else']
    AllOf = properties['allOf']
    AnyOf = properties['anyOf']
    OneOf = properties['oneOf']
    Not = properties['not']
    MultipleOf = properties['multipleOf']
    Maximum = properties['maximum']
    ExclusiveMaximum = properties['exclusiveMaximum']
    Minimum = properties['minimum']
    ExclusiveMinimum = properties['exclusiveMinimum']
    MaxLength = properties['maxLength']
    MinLength = properties['minLength']
    Pattern = properties['pattern']
    MaxItems = properties['maxItems']
    MinItems = properties['minItems']
    UniqueItems = properties['uniqueItems']
    MaxContains = properties['maxContains']
    MinContains = properties['minContains']
    MaxProperties = properties['maxProperties']
    MinProperties = properties['minProperties']
    Required = properties['required']
    DependentRequired = properties['dependentRequired']
    Const = properties['const']
    Enum = properties['enum']
    Type = properties['type']
    Title = properties['title']
    Description = properties['description']
    Default = properties['default']
    Deprecated = properties['deprecated']
    ReadOnly = properties['readOnly']
    WriteOnly = properties['writeOnly']
    Examples = properties['examples']
    Format = properties['format']
    ContentMediaType = properties['contentMediaType']
    ContentEncoding = properties['contentEncoding']
    ContentSchema = properties['contentSchema']

    SchemaArray = defs['schemaArray']
    NonNegativeInteger = defs['nonNegativeInteger']
    NonNegativeIntegerDefault0 = defs['nonNegativeIntegerDefault0']
    SimpleTypes = defs['simpleTypes']
    StringArray = defs['stringArray']
  end
end
