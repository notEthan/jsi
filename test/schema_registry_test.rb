require_relative 'test_helper'

describe 'JSI::SchemaRegistry' do
  let(:schema_registry) { JSI::SchemaRegistry.new }

  describe 'operation' do
    it 'registers a schema and finds it' do
      uri = 'http://jsi/schema_registry/iepm'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      })
      schema_registry.register(resource)
      assert_equal(resource, schema_registry.find(uri))
    end

    it 'registers a nonschema and finds it' do
      uri = 'http://jsi/schema_registry/d7eu'
      resource = JSI::JSONSchemaOrgDraft07.new_schema({}).new_jsi({}, uri: uri)
      schema_registry.register(resource)
      assert_equal(resource, schema_registry.find(uri))
    end
  end
end
