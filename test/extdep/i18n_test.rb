require_relative '../test_helper'

require("i18n")

I18n.backend.store_translations(I18n.default_locale,
  {
    validation: {
      keyword: {
        type: {
          not_match: "i18n type not_match",
        },
      },
    },
  },
)

describe("JSI.translator = I18n.method(:translate)") do
  around do |test|
    begin
      JSI.translator = I18n.method(:translate)
      test.call
    ensure
      JSI.translator = JSI::DEFAULT_TRANSLATOR
    end
  end

  let(:schema) { JSI.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  describe("validation errors") do
    let(:schema_content) do
      {
        "$schema": "http://json-schema.org/draft-07/schema#",
        'properties' => {
          'i18n msg' => {'type' => 'array'},
          'default msg' => false,
        },
      }
    end
    let(:instance) do
      {
        'i18n msg' => {},
        'default msg' => {},
      }
    end

    it("uses i18n stored message, falling back to default message") do
      assert_equal(Set[
        JSI::Validation::Error.new({
          message: "instance object properties are not all valid against corresponding `properties` schemas",
          keyword: "properties",
          additional: {instance_properties_valid: {"i18n msg" => false, "default msg" => false}},
          schema: schema,
          instance_ptr: JSI::Ptr[], instance_document: instance,
          child_errors: Set[
            JSI::Validation::Error.new({
              message: "i18n type not_match",
              keyword: "type",
              additional: {},
              schema: schema["properties"]["i18n msg"],
              instance_ptr: JSI::Ptr["i18n msg"], instance_document: instance,
              child_errors: Set[],
            }),
            JSI::Validation::Error.new({
              message: "instance is not valid against `false` schema",
              keyword: nil,
              additional: {},
              schema: schema["properties"]["default msg"],
              instance_ptr: JSI::Ptr["default msg"], instance_document: instance,
              child_errors: Set[],
            })
          ],
        }),
      ], subject.jsi_validate.validation_errors)
    end
  end
end

$test_report_file_loaded[__FILE__]
