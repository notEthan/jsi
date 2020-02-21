require_relative 'test_helper'

describe JSI::MetaschemaNode do
  let(:jsi_document) { {'properties' => {'properties' => {'additionalProperties' => {'$ref' => '#'}}}} }
  let(:jsi_ptr) { JSI::JSON::Pointer[] }
  let(:metaschema_root_ptr) { JSI::JSON::Pointer[] }
  let(:root_schema_ptr) { JSI::JSON::Pointer[] }
  let(:subject) { JSI::MetaschemaNode.new(jsi_document, jsi_ptr: jsi_ptr, metaschema_root_ptr: jsi_ptr, root_schema_ptr: jsi_ptr) }
  describe 'initialization' do
    it 'initializes' do
      subject
    end
  end
  describe 'json schema draft' do
    it 'type has a schema' do
      assert(JSI::JSONSchemaOrgDraft06.schema.type.jsi_schemas.any?)
    end
  end
end
