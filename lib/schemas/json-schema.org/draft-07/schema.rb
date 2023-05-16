# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-07/schema.json').read)
  JSONSchemaOrgDraft07 = JSI.new_metaschema_module(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft07],
  )

  # the JSI schema module for `http://json-schema.org/draft-07/schema`
  module JSONSchemaOrgDraft07
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft07
  end
end
