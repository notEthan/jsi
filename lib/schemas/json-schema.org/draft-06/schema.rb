# frozen_string_literal: true

module JSI
  schema_id = 'http://json-schema.org/draft/schema' # I don't know why this is not http://json-schema.org/draft-06/schema
  schema_content = ::JSON.parse(File.read(::JSON::Validator.validators[schema_id].metaschema))
  JSONSchemaOrgDraft06 = MetaschemaNode.new(schema_content,
    metaschema_instance_modules: Set[JSI::Schema::Draft06],
  ).tap(&:register_schema).jsi_schema_module

  # the JSI schema module for http://json-schema.org/draft-06/schema
  module JSONSchemaOrgDraft06
  end
end
