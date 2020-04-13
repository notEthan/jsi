# frozen_string_literal: true

module JSI
  schema_content = ::JSON.parse(RESOURCES_PATH.join('json-schema.org/draft-04/schema').read)
  JSONSchemaOrgDraft04 = Metaschema.new(schema_content,
    jsi_metaschema_module: JSI::Schema::Draft04,
  ).tap(&:jsi_register_schema).jsi_schema_module
end
