require_relative 'test_helper'

describe 'JSI::SchemaModule' do
  let(:schema_content) { {'properties' => {'foo' => {'items' => {'type' => 'string'}}}} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft06) }
  let(:schema_module) { schema.jsi_schema_module }
  describe 'accessors and subscripts' do
    it 'returns schemas using accessors and subscripts' do
      assert_equal(schema.properties, schema_module.properties.possibly_schema_node)
      assert_equal(schema.properties['foo'], schema_module.properties['foo'].possibly_schema_node)
      assert_equal(schema.properties['foo'].jsi_schema_module, schema_module.properties['foo'])
      assert_equal(schema.properties['foo'].items, schema_module.properties['foo'].items.possibly_schema_node)
      assert_equal(schema.properties['foo'].items.jsi_schema_module, schema_module.properties['foo'].items)
      assert_equal('string', schema_module.properties['foo'].items.type)
    end
    it 'accessors and subscripts with a metaschema' do
      assert_equal(JSI::JSONSchemaOrgDraft06.schema.properties, JSI::JSONSchemaOrgDraft06.properties.possibly_schema_node)
      assert_equal(JSI::JSONSchemaOrgDraft06.schema.properties['properties'].additionalProperties.jsi_schema_module, JSI::JSONSchemaOrgDraft06.properties['properties'].additionalProperties)
    end
  end
end
