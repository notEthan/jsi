# frozen_string_literal: true

module JSI
  SimpleWrap = JSI::Schema.new({
    "additionalProperties": {"$ref": "#"},
    "items": {"$ref": "#"}
  }).jsi_schema_module

  # SimpleWrap is a JSI schema module which recursively wraps nested structures
  module SimpleWrap
  end
end
