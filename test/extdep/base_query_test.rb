require_relative '../test_helper'

describe JSI::Base do
  let(:schema_content) { {} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }

  describe '#jmespath_search' do
    let(:schema_content) do
      # this is a pared-down JSON-Schema-Test-Suite/test-schema.json
      # that having been a convenient schema to grab and have some instance data for this test
      {
        "$schema": "http://json-schema.org/draft-06/schema#",
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "description": {"type": "string"},
            "schema": {"description": "a valid schema"},
            "tests": {
              "type": "array",
              "items": {"$ref": "#/definitions/test"}
            }
          }
        },
        "definitions": {
          "test": {
            "type": "object",
            "properties": {
              "description": {"type": "string"},
              "data": {},
              "valid": {"type": "boolean"},
            }
          }
        }
      }
    end
    let(:instance) do
      JSON.parse(%q(
        [
          {
            "description": "simple enum validation",
            "schema": {
              "enum": [1, 3]
            },
            "tests": [
              {
                "description": "one of the enum is valid",
                "data": 1,
                "valid": true
              },
              {
                "description": "something else is invalid",
                "data": 4,
                "valid": false
              }
            ]
          },
          {
            "description": "heterogeneous enum validation",
            "schema": {
              "enum": [6, "foo", [], true, {"foo": 12}]
            },
            "tests": [
              {
                "description": "one of the enum is valid",
                "data": [],
                "valid": true
              }
            ]
          }
        ]
      ))
    end

    it 'searches JSIs' do
      assert_equal(
        ["simple enum validation", "heterogeneous enum validation"],
        subject.jmespath_search('[].description')
      )
      subject.jmespath_search('[].schema').each do |test_schema|
        assert_schemas([schema.items.properties['schema']], test_schema)
      end
      assert_equal(
        ["one of the enum is valid", "something else is invalid", "one of the enum is valid"],
        subject.jmespath_search('[].tests[].description')
      )
      assert_equal(
        [1, 4, subject[1].tests[0].data],
        subject.jmespath_search('[].tests[].data')
      )
      assert_schemas([schema.definitions['test'].properties['data']], subject.jmespath_search('[].tests[].data').last)
    end
  end
end
