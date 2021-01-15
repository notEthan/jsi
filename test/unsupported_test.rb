# frozen_string_literal: true

require_relative 'test_helper'

# the behavior described in these tests is not officially supported, but is not expected to break.

describe 'unsupported behavior' do
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }

  describe 'JSI::Schema' do
    # reinstantiating objects at unrecognized paths as schemas is implemented but I don't want to officially
    # support it. the spec states that the behavior is undefined, and the code implementing it is brittle,
    # ugly, and prone to breakage, particularly with $id.
    describe 'reinstantiation' do
      describe 'below another schema' do
        let(:schema_content) do
          YAML.safe_load(<<~YAML
            definitions:
              a:
                $id: http://jsi/test/reinstantiation/below_another/a
                definitions:
                  sub:
                    {}
                unknown:
                  definitions:
                    b:
                      additionalProperties:
                        $ref: "#/definitions/sub"
            items:
              $ref: "#/definitions/a/unknown/definitions/b"
            YAML
          )
        end
        let(:instance) do
          [{'x' => {}}]
        end
        it "instantiates" do
          assert_equal(
            [JSI::Ptr["definitions", "a", "unknown", "definitions", "b"]],
            subject[0].jsi_schemas.map(&:jsi_ptr)
          )
          assert_equal(
            [JSI::Ptr["definitions", "a", "definitions", "sub"]],
            subject[0]['x'].jsi_schemas.map(&:jsi_ptr)
          )
        end
      end
      describe 'below nonschema root' do
        it "instantiates" do
          schema_doc_schema = JSI::JSONSchemaOrgDraft04.new_schema({
            'properties' => {'schema' => {'$ref' => 'http://json-schema.org/draft-04/schema'}}
          })
          schema_doc = schema_doc_schema.new_jsi({
            'schema' => {'$ref' => '#/unknown'},
            'unknown' => {},
          })
          subject = schema_doc.schema.new_jsi({})
          assert_equal(
            [JSI::Ptr["unknown"]],
            subject.jsi_schemas.map(&:jsi_ptr)
          )
        end
      end
      describe 'the origin schema has schemas that do not describe a schema (items)' do
        let(:schema_content) do
          {
            'items' => {'$ref' => '#/unknown'},
            'unknown' => {},
          }
        end
        let(:instance) do
          [{}]
        end
        it "instantiates" do
          assert_equal(
            [JSI::Ptr["unknown"]],
            subject[0].jsi_schemas.map(&:jsi_ptr)
          )
          unknown_schema = subject[0].jsi_schemas.to_a[0]
          # check it's not an items schema like schema.items is
          assert_equal(schema.jsi_schemas, unknown_schema.jsi_schemas)
          refute_equal(schema.items.jsi_schemas, unknown_schema.jsi_schemas)
        end
      end
    end
  end

  describe 'property names which are not strings' do
    ARBITRARY_OBJECT = Object.new
    describe 'arbitrary object property name' do
      let(:schema_content) do
        {
          'properties' => {
            ARBITRARY_OBJECT => {},
          },
        }
      end
      let(:instance) do
        {
          ARBITRARY_OBJECT => {},
        }
      end

      it 'applies properties' do
        assert_is_a(schema.properties[ARBITRARY_OBJECT].jsi_schema_module, subject[ARBITRARY_OBJECT])
      end
    end
    describe 'property name which is an array, described by propertyNames' do
      let(:schema_content) do
        {
          'properties' => {
            [1] => {},
          },
          'propertyNames' => {
            'type' => 'array',
            'items' => {'type' => 'integer'},
          },
        }
      end
      describe 'valid' do
        let(:instance) do
          {
            [] => {},
            [1] => {},
          }
        end
        it 'applies properties' do
          assert_is_a(schema.properties[[1]].jsi_schema_module, subject[[1]])
          assert_equal({}, subject[[]]) # not a jsi

          assert(subject.jsi_valid?)
        end
      end
      describe 'invalid' do
        let(:instance) do
          {
            [] => {},
            [1] => {},
            {} => {},
          }
        end
        it 'applies properties' do
          assert_is_a(schema.properties[[1]].jsi_schema_module, subject[[1]])
          assert_equal({}, subject[[]]) # not a jsi

          assert_equal([
            "instance type does not match `type` value",
            "instance object property names are not all valid against `propertyNames` schema value",
          ], subject.jsi_validate.validation_errors.map(&:message))
        end
      end
    end
  end
end
