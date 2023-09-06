require_relative 'test_helper'

describe JSI::Schema do
  let(:schema) { JSI.new_schema(schema_content) }

  describe 'new_schema' do
    describe 'a ruby literal that looks like json but has symbol keys' do
      let(:line_a) { __LINE__ }
      let(:schema_content) do
        {
          "$schema": "http://json-schema.org/draft-06/schema#",
          "$id": "http://jsi/npjv",
          "properties": {
            "foo": {}
          }
        }
      end
      let(:line_b) { __LINE__ }

      let(:schema_content_from_json) do
        # this is a bit silly
        JSON.parse(File.read(__FILE__).split("\n", -1)[line_a + 1...line_b - 2].join("\n"))
      end

      it 'initializes, stringifying symbol keys' do
        assert_equal(JSI.new_schema(schema_content_from_json), schema)

        assert_equal("http://json-schema.org/draft-06/schema#", schema['$schema'])
        # check that the metaschema id actually corresponds to $schema, particularly since checking
        # $schema is done before the schema content keys are stringified
        assert_equal(["http://json-schema.org/draft-06/schema#"], schema.jsi_schemas.map { |s| s['$id'] })

        # new_schema and new_jsi have different (inconsistent) defaults for stringification of symbol keys.
        # this does mean that, for instances expressed with ruby's json-like colon hash notation,
        # schemas `properties`/`patternProperties` subschemas don't apply to those non-stringified keys.
        assert_schemas([schema.properties["foo"]], schema.new_jsi({"foo" => {}})["foo"]) # string + rocket: yes
        refute_schema(schema.properties["foo"],    schema.new_jsi({"foo": {}})[:foo]) # symbol + colon: no
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
