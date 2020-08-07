require_relative 'test_helper'

describe JSI::MetaschemaNode do
  let(:root_node) do
    JSI::MetaschemaNode.new(jsi_document,
      metaschema_root_ptr: metaschema_root_ptr,
      root_schema_ptr: root_schema_ptr,
    )
  end
  let(:metaschema) { metaschema_root_ptr.evaluate(root_node) }

  describe 'basic' do
    let(:jsi_document) do
      YAML.load(<<~YAML
        properties:
          properties:
            additionalProperties:
              "$ref": "#"
          additionalProperties:
            "$ref": "#"
          "$ref": {}
        YAML
      )
    end
    let(:metaschema_root_ptr) { JSI::JSON::Pointer[] }
    let(:root_schema_ptr) { JSI::JSON::Pointer[] }
    it 'acts like a metaschema' do
      assert_is_a(metaschema.jsi_schema_module, metaschema)
      assert_is_a(metaschema.properties['properties'].jsi_schema_module, metaschema.properties)
      assert_is_a(metaschema.jsi_schema_module, metaschema.properties['properties'])
      assert_is_a(metaschema.jsi_schema_module, metaschema.properties['properties'].additionalProperties)
    end
  end
  describe 'json schema draft' do
    it 'type has a schema' do
      assert(JSI::JSONSchemaOrgDraft06.schema.type.jsi_schemas.any?)
    end
    describe '#jsi_schemas' do
      let(:metaschema) { JSI::JSONSchemaOrgDraft06.schema }
      it 'has jsi_schemas' do
        assert_equal(Set[metaschema], metaschema.jsi_schemas)
        assert_equal(Set[metaschema.properties['properties']], metaschema.properties.jsi_schemas)
      end
    end
  end
end
