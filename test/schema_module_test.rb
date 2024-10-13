require_relative 'test_helper'

SchemaModuleTestModule = JSI.new_schema_module({
  '$schema' => 'http://json-schema.org/draft-07/schema#',
  'title' => 'a9b7',
  'properties' => {'foo' => {'items' => {'type' => 'string'}}},
  'additionalProperties' => {},
})

describe 'JSI::SchemaModule' do
  let(:schema_content) { {'properties' => {'foo' => {'items' => {'type' => 'string'}}}} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft06) }
  let(:schema_module) { schema.jsi_schema_module }
  describe 'accessors and subscripts' do
    it 'returns schemas using accessors and subscripts' do
      assert_is_a(JSI::SchemaModule::Connection, schema_module.properties)
      assert_equal(schema.properties, schema_module.properties.jsi_node)
      assert_equal(schema.properties['foo'], schema_module.properties['foo'].jsi_node)
      assert_equal(schema.properties['foo'].jsi_schema_module, schema_module.properties['foo'])
      assert_equal(schema.properties['foo'].items, schema_module.properties['foo'].items.jsi_node)
      assert_equal(schema.properties['foo'].items.jsi_schema_module, schema_module.properties['foo'].items)
      assert_equal('string', schema_module.properties['foo'].items.type)
    end
    it('accessors and subscripts with a meta-schema') do
      assert_is_a(JSI::SchemaModule::Connection, JSI::JSONSchemaDraft06.properties)
      assert_equal(JSI::JSONSchemaDraft06.schema.properties, JSI::JSONSchemaDraft06.properties.jsi_node)
      assert_equal(JSI::JSONSchemaDraft06.schema.properties['properties'].additionalProperties.jsi_schema_module, JSI::JSONSchemaDraft06.properties['properties'].additionalProperties)
      assert_equal(JSI::JSONSchemaDraft06.schema.properties['properties'].additionalProperties, JSI::JSONSchemaDraft06.properties['properties'].additionalProperties.jsi_node)
    end

    describe 'named properties of a schema module connection' do
      # the json schema meta-schemas don't describe any named properties of any objects that aren't schemas.
      # we need a meta-schema that does.
      let(:metaschema) do
        document = YAML.load(<<~YAML
          properties:
            properties:
              additionalProperties:
                "$ref": "#"
            additionalProperties:
              "$ref": "#"
            bar:
              properties:
                baz: {}
                sch:
                  "$ref": "#"
          bar:
            baz: {}
            sch: {}
          YAML
        )
        JSI.new_metaschema(document, schema_implementation_modules: [JSI::Schema::Draft06])
      end

      it 'defines accessors for the connection' do
        assert_equal(metaschema.bar.baz, metaschema.jsi_schema_module.bar.baz.jsi_node)
        assert_equal(metaschema.bar.sch.jsi_schema_module, metaschema.jsi_schema_module.bar.sch)
        schema = metaschema.new_schema({'bar' => {'baz' => {}, 'sch' => {}}})
        assert_equal(schema.bar.baz, schema.jsi_schema_module.bar.baz.jsi_node)
        assert_equal(schema.bar.sch.jsi_schema_module, schema.jsi_schema_module.bar.sch)
      end
    end
  end
  describe '.inspect, .to_s' do
    it 'shows the name relative to a named ancestor schema module' do
      assert_equal(
        'SchemaModuleTestModule.properties (JSI::SchemaModule::Connection)',
        SchemaModuleTestModule.properties.inspect
      )
      assert_equal(SchemaModuleTestModule.properties.inspect, SchemaModuleTestModule.properties.to_s)
      assert_equal(
        'SchemaModuleTestModule.properties["foo"].items (JSI Schema Module)',
        SchemaModuleTestModule.properties["foo"].items.inspect
      )
      assert_equal(SchemaModuleTestModule.properties["foo"].items.inspect, SchemaModuleTestModule.properties["foo"].items.to_s)
    end
    it 'shows a pointer fragment uri with no named ancestor schema module' do
      mod = JSI::JSONSchemaDraft07.new_schema_module({
        'title' => 'lhzm', 'properties' => {'foo' => {'items' => {'type' => 'string'}}}
      })
      assert_equal(
        '(JSI::SchemaModule::Connection: #/properties)',
        mod.properties.inspect
      )
      assert_equal(mod.properties.inspect, mod.properties.to_s)
      assert_equal(
        '(JSI Schema Module: #/properties/foo/items)',
        mod.properties["foo"].items.inspect
      )
      assert_equal(mod.properties["foo"].items.inspect, mod.properties["foo"].items.to_s)
    end
  end

  describe '.schema' do
    it 'is its schema' do
      assert_equal(schema, schema_module.schema)
    end
  end

  describe('SchemaModule::MetaSchemaModule') do
    it 'extends a module which describes a schema' do
      assert(JSI::JSONSchemaDraft07.is_a?(JSI::SchemaModule::MetaSchemaModule))
    end

    it '#new_schema' do
      schema = JSI::JSONSchemaDraft07.new_schema({})
      assert_is_a(JSI::JSONSchemaDraft07, schema)
      assert_equal(JSI::JSONSchemaDraft07.schema.new_schema({}), schema)
    end

    it '#new_schema_module' do
      mod = JSI::JSONSchemaDraft07.new_schema_module({})
      assert_equal(mod.schema.jsi_schema_module, mod)
    end
  end

  describe 'block given to SchemaModule/Connection reader' do
    it '`module_exec`s (Connection#[])' do
      SchemaModuleTestModule.properties['foo'] do
        def x
          :x
        end
      end
      assert_equal(:x, SchemaModuleTestModule.new_jsi({'foo' => {}}).foo.x)
    end
    it '`module_exec`s (SchemaModule#[])' do
      SchemaModuleTestModule.additionalProperties do
        def x
          :x
        end
      end
      assert_equal(:x, SchemaModuleTestModule.new_jsi({'qux' => {}})['qux'].x)
    end
  end
end

$test_report_file_loaded[__FILE__]
