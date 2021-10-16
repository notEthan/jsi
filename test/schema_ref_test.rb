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

    describe 'same anchor, parent and child resources' do
      let(:schema) do
        JSI::JSONSchemaOrgDraft06.new_schema(JSON.parse(%q({
          "$id": "http://jsi/schema_ref/m6xe",
          "definitions": {
            "ref": {"$ref": "#X"},
            "child": {
              "$id": "#X",
              "definitions": {
                "ref": {"$ref": "#X"},
                "rel": {
                  "$id": "svl3",
                  "definitions": {
                    "ref": {"$ref": "#X"},
                    "x": {"$id": "#X"}
                  }
                }
              }
            }
          }
        })))
      end

      it 'resolves' do
        assert_equal(
          JSI::SchemaSet[schema.definitions['child']],
          schema.definitions['ref'].new_jsi({}).jsi_schemas
        )
        assert_equal(
          JSI::SchemaSet[schema.definitions['child']],
          schema.definitions['child'].definitions['ref'].new_jsi({}).jsi_schemas
        )
        assert_equal(
          JSI::SchemaSet[schema.definitions['child'].definitions['rel'].definitions['x']],
          schema.definitions['child'].definitions['rel'].definitions['ref'].new_jsi({}).jsi_schemas
        )
      end
    end

    describe 'anchor alongside absolute uri in child' do
      let(:schema) do
        JSI::JSONSchemaOrgDraft06.new_schema(JSON.parse(%q({
          "$id": "http://jsi/schema_ref/os0e",
          "definitions": {
            "ref": {"$ref": "#X"},
            "child": {
              "$id": "#X",
              "definitions": {
                "ref": {"$ref": "#X"},
                "x": {
                  "$id": "x99u#X"
                }
              }
            }
          }
        })))
      end

      it 'resolves' do
        assert_equal(
          JSI::SchemaSet[schema.definitions['child']],
          schema.definitions['ref'].new_jsi({}).jsi_schemas
        )
        assert_equal(
          JSI::SchemaSet[schema.definitions['child']],
          schema.definitions['child'].definitions['ref'].new_jsi({}).jsi_schemas
        )
      end
    end
  end
end
