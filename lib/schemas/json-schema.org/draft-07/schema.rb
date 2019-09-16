# frozen_string_literal: true

module JSI
  schema_content = ::JSON.parse(RESOURCES_PATH.join('json-schema.org/draft-07/schema').read)
  JSONSchemaOrgDraft06 = Metaschema.new(schema_content,
    jsi_schema_instance_modules: Set[JSI::Schema::Draft07],
  ).tap(&:jsi_register_schema).jsi_schema_module
end
