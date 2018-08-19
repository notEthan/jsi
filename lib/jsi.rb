require "jsi/version"
require "pp"
require "jsi/json-schema-fragments"

module JSI
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  class Bug < NotImplementedError
  end
end
