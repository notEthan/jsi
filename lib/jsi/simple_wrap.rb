# frozen_string_literal: true

module JSI
  SimpleWrap = JSI::JSONSchemaOrgDraft06.new_schema({
    "additionalProperties": {"$ref": "#"},
    "items": {"$ref": "#"}
  }).jsi_schema_module

  # SimpleWrap is a JSI schema module which recursively wraps nested structures
  module SimpleWrap
  end
end
