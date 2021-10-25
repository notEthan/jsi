# frozen_string_literal: true

module JSI
  SimpleWrap = JSI::JSONSchemaOrgDraft06.new_schema_module({
    "additionalProperties": {"$ref": "#"},
    "items": {"$ref": "#"}
  })

  # SimpleWrap is a JSI schema module which recursively wraps nested structures
  module SimpleWrap
  end
end
