# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-06/schema.json').read)
  JSONSchemaOrgDraft06 = MetaschemaNode.new(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft06],
  ).jsi_schema_module

  # the JSI schema module for `http://json-schema.org/draft-06/schema`
  module JSONSchemaOrgDraft06
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft06
  end
end
