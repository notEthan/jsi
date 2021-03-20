require_relative 'test_helper'

describe JSI::Schema::Ref do
  describe 'anchors' do
    describe 'no anchor' do
      let(:schema) do
        JSI::JSONSchemaOrgDraft06.new_schema({"$ref" => "#no"})
      end

      it 'finds none' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
        assert_match(/could not find schema by fragment/, err.message)
      end
    end

    describe 'conflicting siblings' do
      let(:schema) do
        JSI::JSONSchemaOrgDraft06.new_schema(YAML.safe_load(%q({
          "definitions": {
            "sibling1": {"$id": "#collide"},
            "sibling2": {"$id": "#collide"},
            "ref": {"$ref": "#collide"}
          }
        })))
      end

      it 'finds a collision' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.definitions['ref'].new_jsi({}) }
        assert_match(/found multiple schemas for plain name fragment/, err.message)
      end
    end
  end
end