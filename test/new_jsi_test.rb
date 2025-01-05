require_relative 'test_helper'

describe 'new_jsi, new_schema' do
  let(:other_registry) { JSI::DEFAULT_REGISTRY.dup }

  describe 'new_schema' do
    it 'initializes with a block' do
      schema1 = JSI.new_schema({'$id' => 'tag:gxif'}, default_metaschema: JSI::JSONSchemaDraft07) do
        define_method(:foo) { :foo }
      end
      schema2 = JSI::JSONSchemaDraft07.new_schema({'$id' => 'tag:ijpa'}) do
        define_method(:foo) { :foo }
      end
      assert_equal(:foo, schema1.new_jsi([]).foo)
      assert_equal(:foo, schema2.new_jsi([]).foo)
    end
  end

  describe('registration') do
    it('JSI.new_schema registers schemas by default') do
      uri = 'http://jsi/registry/m7ty'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      })
      assert_equal(resource, JSI.registry.find(uri))
    end

    it('JSI.new_schema registers schemas by default in a specified registry') do
      uri = 'http://jsi/registry/lzr5'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, registry: other_registry)
      assert_equal(resource, other_registry.find(uri))
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('JSI.new_schema does not register with register: false') do
      uri = 'http://jsi/registry/ah0e'
      JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, registry: other_registry, register: false)
      assert_raises(JSI::ResolutionError) { other_registry.find(uri) }
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it("Schema::MetaSchema#new_schema does not register with registry: nil") do
      uri = 'http://jsi/registry/qvjd'
      # note: this uses Schema::MetaSchema#new_schema, not JSI.new_schema, because
      # passing registry: nil to the latter would cause $schema to fail to resolve
      JSI::JSONSchemaDraft07.new_schema({
        '$id' => uri,
      }, registry: nil)
      assert_raises(JSI::ResolutionError) { other_registry.find(uri) }
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('Schema::MetaSchema#new_schema registers schemas by default') do
      uri = 'http://jsi/registry/4nqz'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri})
      assert_equal(resource, JSI.registry.find(uri))
    end

    it('Schema::MetaSchema#new_schema registers schemas by default in a specified registry') do
      uri = 'http://jsi/registry/bmfh'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, registry: other_registry)
      assert_equal(resource, other_registry.find(uri))
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('Schema::MetaSchema#new_schema does not register with register: false') do
      uri = 'http://jsi/registry/mr2n'
      JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, registry: other_registry, register: false)
      assert_raises(JSI::ResolutionError) { other_registry.find(uri) }
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('SchemaSet#new_jsi registers contained schemas with register: true') do
      uri = 'http://jsi/registry/dm4r'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource = resource_schema.new_jsi({'aschema' => {'$id' => uri}}, register: true)
      assert_equal(resource.aschema, JSI.registry.find(uri))
    end

    it('SchemaSet#new_jsi registers schemas with register: true in a specified registry') do
      uri = 'http://jsi/registry/o2cu'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource = resource_schema.new_jsi({'aschema' => {'$id' => uri}}, register: true, registry: other_registry)
      assert_equal(resource.aschema, other_registry.find(uri))
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('SchemaSet#new_jsi does not register by default') do
      uri = 'http://jsi/registry/hyej'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource_schema.new_jsi({'aschema' => {'$id' => uri}}, registry: other_registry)
      assert_raises(JSI::ResolutionError) { other_registry.find(uri) }
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it("SchemaSet#new_jsi does not register with registry: nil despite register: true") do
      uri = 'http://jsi/registry/y9qy'
      resource_schema = JSI::JSONSchemaDraft07.new_schema({
        'properties' => {'aschema' => {'$ref': 'http://json-schema.org/draft-07/schema'}}
      })
      resource_schema.new_jsi({'aschema' => {'$id' => uri}}, registry: nil, register: true)
      assert_raises(JSI::ResolutionError) { other_registry.find(uri) }
      assert_raises(JSI::ResolutionError) { JSI.registry.find(uri) }
    end

    it('resolves $ref using the specified registry') do
      uri = 'http://jsi/registry/8ol5'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      }, registry: other_registry)
      ref_schema = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$ref' => uri,
      }, registry: other_registry)
      jsi = ref_schema.new_jsi({})
      assert_schemas([resource], jsi)
    end
  end

  describe("$schema lookup") do
    it('resolves $schema using the specified registry') do
      uri = 'http://jsi/registry/kzwz'
      metaschema_document = JSI::JSONSchemaDraft07.schema.jsi_node_content.merge({'$id' => uri, '$schema' => uri})
      metaschema = JSI.new_metaschema(metaschema_document, dialect: JSI::Schema::Draft07::DIALECT)
      other_registry.register(metaschema)

      assert_raises(JSI::ResolutionError) { JSI.new_schema({'$schema' => uri}) }
      schema = JSI.new_schema({'$schema' => uri}, registry: other_registry)
      assert_schemas([metaschema], schema)
    end

    it("cannot resolve $schema with no registry") do
      assert_raises(JSI::ResolutionError) do
        JSI.new_schema({'$schema' => "http://json-schema.org/draft-07/schema#"}, registry: nil)
      end
    end
  end
end
