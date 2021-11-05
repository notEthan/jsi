# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-04/schema.json').read)
  JSONSchemaOrgDraft04 = MetaschemaNode.new(metaschema_document,
    metaschema_instance_modules: [JSI::Schema::Draft04],
  ).jsi_schema_module

  # the JSI schema module for `http://json-schema.org/draft-04/schema`
  module JSONSchemaOrgDraft04
  end
end
