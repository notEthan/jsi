module JSI
  schema_id = 'http://json-schema.org/draft-04/schema'
  schema_content = ::JSON.parse(File.read(::JSON::Validator.validators[schema_id].metaschema))
  JSONSchemaOrgDraft04Schema = MetaschemaNode.new(schema_content)
  JSONSchemaOrgDraft04 = JSONSchemaOrgDraft04Schema.jsi_schema_class
end
