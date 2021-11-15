require_relative 'test_helper'

SchemaModuleTestModule = JSI.new_schema_module({
  '$schema' => 'http://json-schema.org/draft-07/schema#',
  'title' => 'a9b7',
  'properties' => {'foo' => {'items' => {'type' => 'string'}}}
})

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
  describe '.inspect' do
    it 'shows the name relative to a named parent module' do
      assert_equal(
        'SchemaModuleTestModule.properties (JSI wrapper for Schema Module)',
        SchemaModuleTestModule.properties.inspect
      )
      assert_equal(
        'SchemaModuleTestModule.properties["foo"].items (JSI Schema Module)',
        SchemaModuleTestModule.properties["foo"].items.inspect
      )
    end
    it 'shows a pointer fragment uri with no named parent module' do
      mod = JSI::JSONSchemaOrgDraft07.new_schema_module({
        'title' => 'lhzm', 'properties' => {'foo' => {'items' => {'type' => 'string'}}}
      })
      assert_equal(
        '(JSI wrapper for Schema Module: #/properties)',
        mod.properties.inspect
      )
      assert_equal(
        '(JSI Schema Module: #/properties/foo/items)',
        mod.properties["foo"].items.inspect
      )
    end
  end

  describe 'DescribesSchemaModule' do
    it 'extends a module which describes a schema' do
      assert(JSI::JSONSchemaOrgDraft07.is_a?(JSI::DescribesSchemaModule))
    end

    it '#new_schema' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({})
      assert_is_a(JSI::JSONSchemaOrgDraft07, schema)
      assert_equal(JSI::JSONSchemaOrgDraft07.schema.new_schema({}), schema)
    end

    it '#new_schema_module' do
      mod = JSI::JSONSchemaOrgDraft07.new_schema_module({})
      assert_equal(JSI::JSONSchemaOrgDraft07.new_schema({}).jsi_schema_module, mod)
    end
  end
end
