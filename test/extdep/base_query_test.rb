require_relative '../test_helper'

describe JSI::Base do
  let(:schema_content) { {} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }

  describe '#jmespath_search' do
    let(:schema_content) do
      JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').read)
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
