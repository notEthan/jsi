require_relative('test_helper')

describe("strict 2020-12 meta-schema") do
  describe("instantiating") do
    it("instantiates, validates") do
      content = JSI::Util.json_parse_freeze(JSI::RESOURCES_PATH.join('schemas/2020-12_strict.json').read)
      strict_metaschema = JSI.new_schema(content, after_initialize: proc { |node| node.describes_schema! if node.jsi_ptr.root? })

      strict_schema = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/strict",
        "unknown": {},
        "properties": {
          "foo": {"unknown": ""},
        },
      })

      validation_errors = strict_schema.jsi_validate.each_validation_error

      expected_errors_attrs = [
        {schema: strict_metaschema.unevaluatedProperties, instance_ptr: JSI::Ptr["properties", "foo", "unknown"]},
        {schema: strict_metaschema.unevaluatedProperties, instance_ptr: JSI::Ptr["unknown"]},
      ]
      expected_errors_attrs.each do |error_attrs|
        assert(validation_errors.any? do |validation_error|
          error_attrs.all? do |attr, value|
            validation_error[attr] == value
          end
        end)
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
