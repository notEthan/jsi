require_relative 'test_helper'

describe JSI::MetaschemaNode do
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
    let(:jsi_ptr) { JSI::JSON::Pointer[] }
    let(:metaschema_root_ptr) { JSI::JSON::Pointer[] }
    let(:root_schema_ptr) { JSI::JSON::Pointer[] }
    let(:subject) do
      JSI::MetaschemaNode.new(jsi_document,
        jsi_ptr: jsi_ptr,
        metaschema_root_ptr: jsi_ptr,
        root_schema_ptr: jsi_ptr,
      )
    end
    it 'acts like a metaschema' do
      assert_is_a(subject.jsi_schema_module, subject)
      assert_is_a(subject.properties['properties'].jsi_schema_module, subject.properties)
      assert_is_a(subject.jsi_schema_module, subject.properties['properties'])
      assert_is_a(subject.jsi_schema_module, subject.properties['properties'].additionalProperties)
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
