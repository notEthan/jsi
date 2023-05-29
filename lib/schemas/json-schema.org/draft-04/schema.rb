# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-04/schema.json').read)
  JSONSchemaOrgDraft04 = MetaschemaNode.new(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft04],
  ).jsi_schema_module

  # in draft 4, boolean schemas are not described in the root, but on anyOf schemas on
  # properties/additionalProperties and properties/additionalItems.
  # these still describe schemas, despite not being described by the metaschema.
  also_describe_schemas =
    JSONSchemaOrgDraft04.schema["properties"]["additionalProperties"]["anyOf"] +
    JSONSchemaOrgDraft04.schema["properties"]["additionalItems"]["anyOf"]
  also_describe_schemas.each do |schema|
    schema.describes_schema!([JSI::Schema::Draft04])
  end

  # the JSI schema module for `http://json-schema.org/draft-04/schema`
  module JSONSchemaOrgDraft04
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft04
  end
end
