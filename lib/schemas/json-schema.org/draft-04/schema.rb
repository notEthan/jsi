# frozen_string_literal: true

module JSI
  schema_content = ::JSON.parse(RESOURCES_PATH.join('json-schema.org/draft-04/schema').read)
  JSONSchemaOrgDraft04 = MetaschemaNode.new(schema_content,
    root_basic_schema: JSI::BasicSchema::Draft04.new(JSI::JSON::Pointer[], schema_content)
  ).tap(&:jsi_register_schema).jsi_schema_module
end
