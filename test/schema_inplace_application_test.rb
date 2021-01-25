require_relative 'test_helper'

describe 'JSI Schema inplace application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
  }.each do |name, metaschema|
    describe "#{name} inplace $ref application" do
      let(:metaschema) { metaschema }
      describe '$ref' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies $ref, excludes the schema containing $ref' do
          assert_equal(Set[
            schema.definitions['A'],
          ], subject.jsi_schemas)
          refute_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.definitions['A'].jsi_schema_module, subject)
        end
      end
      describe '$ref nested' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A:
                $ref: "#/definitions/B"
              B:
                {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies final $ref' do
          assert_equal(Set[
            schema.definitions['B'],
          ], subject.jsi_schemas)
          refute_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.definitions['A'].jsi_schema_module, subject)
          assert_is_a(schema.definitions['B'].jsi_schema_module, subject)
        end
      end
      describe '$ref sibling applicators' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            allOf:
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'ignores' do
          assert_equal(Set[
            schema.definitions['A'],
          ], subject.jsi_schemas)
          refute_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.definitions['A'].jsi_schema_module, subject)
          refute_is_a(schema.allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'applicators through $ref target' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A:
                allOf:
                  - {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies' do
          assert_equal(Set[
            schema.definitions['A'],
            schema.definitions['A'].allOf[0],
          ], subject.jsi_schemas)
          refute_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.definitions['A'].jsi_schema_module, subject)
          assert_is_a(schema.definitions['A'].allOf[0].jsi_schema_module, subject)
        end
      end
    end
  end
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
  }.each do |name, metaschema|
    describe "#{name} inplace allOf, anyOf, oneOf application" do
      let(:metaschema) { metaschema }
      describe 'allOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - {}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies' do
          assert_equal(Set[
            schema,
            schema.allOf[0],
            schema.allOf[1],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].jsi_schema_module, subject)
          assert_is_a(schema.allOf[1].jsi_schema_module, subject)
        end
      end
      describe 'applicators through allOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - allOf:
                  - {}
              - oneOf:
                  - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies all' do
          assert_equal(Set[
            schema,
            schema.allOf[0],
            schema.allOf[0].allOf[0],
            schema.allOf[1],
            schema.allOf[1].oneOf[0],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].allOf[0].jsi_schema_module, subject)
          assert_is_a(schema.allOf[1].jsi_schema_module, subject)
          assert_is_a(schema.allOf[1].oneOf[0].jsi_schema_module, subject)
        end
      end
      describe 'allOf failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - allOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'still applies all' do
          assert_equal(Set[
            schema,
            schema.allOf[0],
            schema.allOf[0].allOf[0],
            schema.allOf[0].allOf[1],
            schema.allOf[1],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].allOf[0].jsi_schema_module, subject)
          assert_is_a(schema.allOf[0].allOf[1].jsi_schema_module, subject)
          assert_is_a(schema.allOf[1].jsi_schema_module, subject)
          refute_is_a(schema.allOf[1].oneOf[0].jsi_schema_module, subject)
        end
      end
      describe 'anyOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - {}
              - {type: integer}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies the ones that validate' do
          assert_equal(Set[
            schema,
            schema.anyOf[0],
            schema.anyOf[2],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.anyOf[0].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[1].jsi_schema_module, subject)
          assert_is_a(schema.anyOf[2].jsi_schema_module, subject)
        end
      end
      describe 'applicators through anyOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - anyOf:
                  - {}
              - oneOf:
                  - {}
              - allOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies those that validate' do
          assert_equal(Set[
            schema,
            schema.anyOf[0],
            schema.anyOf[0].anyOf[0],
            schema.anyOf[1],
            schema.anyOf[1].oneOf[0],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          assert_is_a(schema.anyOf[0].jsi_schema_module, subject)
          assert_is_a(schema.anyOf[0].anyOf[0].jsi_schema_module, subject)
          assert_is_a(schema.anyOf[1].jsi_schema_module, subject)
          assert_is_a(schema.anyOf[1].oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[2].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[2].allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'anyOf, all failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - anyOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                  - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies none' do
          assert_equal(Set[
            schema,
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.anyOf[0].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[0].anyOf[0].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[0].anyOf[1].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[1].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[1].oneOf[0].jsi_schema_module, subject)
        end
      end
      describe 'oneOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - {not: {}}
              - {type: integer}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies the one that validates' do
          assert_equal(Set[
            schema,
            schema.oneOf[2],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[1].jsi_schema_module, subject)
          assert_is_a(schema.oneOf[2].jsi_schema_module, subject)
        end
      end
      describe 'applicators through oneOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - oneOf:
                  - {}
                  - {}
              - anyOf:
                  - {}
              - allOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies one' do
          assert_equal(Set[
            schema,
            schema.oneOf[1],
            schema.oneOf[1].anyOf[0],
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[1].jsi_schema_module, subject)
          assert_is_a(schema.oneOf[1].jsi_schema_module, subject)
          assert_is_a(schema.oneOf[1].anyOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[2].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[2].allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'oneOf, all failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - oneOf:
                  - {type: integer}
                  - {not: {}}
              - allOf:
                  - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies none' do
          assert_equal(Set[
            schema,
          ], subject.jsi_schemas)
          assert_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[1].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[1].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[1].allOf[0].jsi_schema_module, subject)
        end
      end
    end
  end
end
