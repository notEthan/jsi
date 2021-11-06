require_relative 'test_helper'

describe JSI::Schema::Ref do
  let(:schema) do
    JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07)
  end

  describe 'anchors' do
    describe 'no anchor' do
      let(:schema_content) do
        {"$ref" => "#no"}
      end

      it 'finds none' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
        assert_match(/could not find schema by fragment/, err.message)
      end
    end

    describe 'conflicting siblings' do
      let(:schema_content) do
        JSON.parse(%q({
          "definitions": {
            "sibling1": {"$id": "#collide"},
            "sibling2": {"$id": "#collide"},
            "ref": {"$ref": "#collide"}
          }
        }))
      end

      it 'finds a collision' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.definitions['ref'].new_jsi({}) }
        assert_match(/found multiple schemas for plain name fragment/, err.message)
      end
    end
  end

  describe 'not a schema' do
    describe 'remote ref in resource root nonschema' do
      let(:uri) { 'http://jsi/ref_to_not_a_schema' }
      let(:schema_content) do
        {'$ref' => uri}
      end

      it 'finds a thing that is not a schema' do
        JSI.schema_registry.autoload_uri(uri) do
          JSI.new_schema({}).new_jsi({}, uri: uri)
        end

        err = assert_raises(JSI::Schema::NotASchemaError) { schema.new_jsi({}) }
        msg = <<~MSG
          object identified by uri http://jsi/ref_to_not_a_schema is not a schema:
          \#{<JSI>}
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end
  end
end
