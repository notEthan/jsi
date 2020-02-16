# frozen_string_literal: true

module JSI
  schema_content = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-06/schema.json').read)
  JSONSchemaOrgDraft06 = MetaschemaNode.new(schema_content,
    metaschema_instance_modules: [JSI::Schema::Draft06],
  ).jsi_schema_module

  # the JSI schema module for http://json-schema.org/draft-06/schema
  module JSONSchemaOrgDraft06
  end
end
