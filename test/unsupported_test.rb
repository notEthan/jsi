# frozen_string_literal: true

require_relative 'test_helper'

# the behavior described in these tests is not officially supported, but is not expected to break.

describe 'unsupported behavior' do
  let(:schema) { JSI.new_schema(schema_content) }
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
    end
  end
end
