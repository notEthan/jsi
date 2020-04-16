require_relative 'test_helper'

describe JSI::Metaschema do
  let(:jsi_document) do
    {
      'properties' => {
        'properties' => {
          'additionalProperties' => {
            '$ref' => '#'
          }
        },
        'additionalProperties' => {
          '$ref' => '#'
        },
'$ref' => {}, # and type?
      }
    }
  end
  let(:jsi_ptr) { JSI::JSON::Pointer[] }
  let(:subject) do
    JSI::Metaschema.new(jsi_document,
      jsi_schema_instance_modules: Set[JSI::Schema::Draft201909],
    )
  end
  describe 'initialization' do
    it 'initializes' do
      subject
    end
    it 'acts like a metaschema' do
      assert_is_a(subject.jsi_schema_module, subject)
      assert_is_a(subject.properties['properties'].jsi_schema_module, subject.properties)
      assert_is_a(subject.jsi_schema_module, subject.properties['properties'])
      assert_is_a(subject.jsi_schema_module, subject.properties['properties'].additionalProperties)
# TODO describe $ref as well 
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
  describe 'what if additionalProperties could be a number' do
    let(:jsi_document) do
      {
        'properties' => {
          'properties' => {
            'additionalProperties' => {
              '$ref' => '#',
            }
          }
        }
      }
    end
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
