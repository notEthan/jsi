require_relative 'test_helper'

describe 'new_jsi, new_schema' do
  describe 'new_schema' do
    it 'initializes with a block' do
      schema1 = JSI.new_schema({'$id' => 'tag:gxif'}, default_metaschema: JSI::JSONSchemaOrgDraft07) do
        define_method(:foo) { :foo }
      end
      schema2 = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'tag:ijpa'}) do
        define_method(:foo) { :foo }
      end
      assert_equal(:foo, schema1.new_jsi([]).foo)
      assert_equal(:foo, schema2.new_jsi([]).foo)
    end
  end

  describe('registration') do
    let(:other_schema_registry) { JSI::DEFAULT_SCHEMA_REGISTRY.dup }

    it('JSI.new_schema registers schemas by default') do
      uri = 'http://jsi/schema_registry/m7ty'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      })
      assert_equal(resource, JSI.schema_registry.find(uri))
    end

    it('JSI.new_schema registers schemas by default in a specified registry') do
      uri = 'http://jsi/schema_registry/lzr5'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, schema_registry: other_schema_registry)
      assert_equal(resource, other_schema_registry.find(uri))
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('JSI.new_schema does not register with register: false') do
      uri = 'http://jsi/schema_registry/ah0e'
      JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, schema_registry: other_schema_registry, register: false)
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { other_schema_registry.find(uri) }
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('JSI.new_schema does not register with schema_registry: nil') do
      uri = 'http://jsi/schema_registry/qvjd'
      JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, schema_registry: nil)
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { other_schema_registry.find(uri) }
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('DescribesSchema#new_schema registers schemas by default') do
      uri = 'http://jsi/schema_registry/4nqz'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri})
      assert_equal(resource, JSI.schema_registry.find(uri))
    end

    it('DescribesSchema#new_schema registers schemas by default in a specified registry') do
      uri = 'http://jsi/schema_registry/bmfh'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, schema_registry: other_schema_registry)
      assert_equal(resource, other_schema_registry.find(uri))
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('DescribesSchema#new_schema does not register with register: false') do
      uri = 'http://jsi/schema_registry/mr2n'
      JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, schema_registry: other_schema_registry, register: false)
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { other_schema_registry.find(uri) }
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('SchemaSet#new_jsi registers contained schemas with register: true') do
      uri = 'http://jsi/schema_registry/dm4r'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource = resource_schema.new_jsi({'aschema' => {'$id' => uri}}, register: true)
      assert_equal(resource.aschema, JSI.schema_registry.find(uri))
    end

    it('SchemaSet#new_jsi registers schemas with register: true in a specified registry') do
      uri = 'http://jsi/schema_registry/o2cu'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource = resource_schema.new_jsi({'aschema' => {'$id' => uri}}, register: true, schema_registry: other_schema_registry)
      assert_equal(resource.aschema, other_schema_registry.find(uri))
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('SchemaSet#new_jsi does not register by default') do
      uri = 'http://jsi/schema_registry/hyej'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource_schema.new_jsi({'aschema' => {'$id' => uri}}, schema_registry: other_schema_registry)
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { other_schema_registry.find(uri) }
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('SchemaSet#new_jsi does not register with schema_registry: nil despite register: true') do
      uri = 'http://jsi/schema_registry/y9qy'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource_schema.new_jsi({'aschema' => {'$id' => uri}}, schema_registry: nil, register: true)
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { other_schema_registry.find(uri) }
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.schema_registry.find(uri) }
    end

    it('resolves $ref using the specified registry') do
      uri = 'http://jsi/schema_registry/8ol5'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, schema_registry: other_schema_registry)
      ref_schema = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$ref' => uri,
      }, schema_registry: other_schema_registry)
      jsi = ref_schema.new_jsi({})
      assert_schemas([resource], jsi)
    end

    it('resolves $schema using the specified registry') do
      uri = 'http://jsi/schema_registry/kzwz'
      metaschema_document = JSI::JSONSchemaDraft07.schema.jsi_node_content.merge({'$id' => uri, '$schema' => uri})
      metaschema = JSI.new_metaschema(metaschema_document, schema_implementation_modules: [JSI::Schema::Draft07])
      other_schema_registry.register(metaschema)

      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI.new_schema({'$schema' => uri}) }
      schema = JSI.new_schema({'$schema' => uri}, schema_registry: other_schema_registry)
      assert_schemas([metaschema], schema)
    end
  end
end
