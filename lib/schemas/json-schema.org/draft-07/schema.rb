# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-07/schema.json').read)
  JSONSchemaOrgDraft07 = MetaschemaNode.new(metaschema_document,
    metaschema_instance_modules: [JSI::Schema::Draft07],
  ).jsi_schema_module
end
