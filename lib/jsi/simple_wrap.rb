module JSI
  SimpleWrap = JSI.class_for_schema({"additionalProperties": {"$ref": "#"}, "items": {"$ref": "#"}})

  # SimpleWrap is a JSI class which recursively wraps nested structures
  class SimpleWrap
  end
end
