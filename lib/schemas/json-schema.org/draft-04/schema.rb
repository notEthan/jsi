# frozen_string_literal: true

module JSI
  schema_id = 'http://json-schema.org/draft-04/schema'
  schema_content = ::JSON.parse(File.read(::JSON::Validator.validators[schema_id].metaschema))
  JSONSchemaOrgDraft04 = MetaschemaNode.new(schema_content).jsi_schema_module
end
