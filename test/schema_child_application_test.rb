require_relative 'test_helper'

describe 'JSI Schema child application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
    draft07: JSI::JSONSchemaOrgDraft07,
  }.each do |name, metaschema|
    describe "#{name} child items / additionalItems application" do
      let(:metaschema) { metaschema }
      describe 'items' do
        let(:schema_content) do
          YAML.load(<<~YAML
            items: {}
            YAML
          )
        end
        let(:instance) { [{}] }
        it 'applies items' do
          assert_equal(Set[
            schema.items,
          ], subject[0].jsi_schemas)
          assert_is_a(schema.items.jsi_schema_module, subject[0])
        end
      end
      describe 'items array' do
        let(:schema_content) do
          YAML.load(<<~YAML
            items: [{}]
            YAML
          )
        end
        let(:instance) { [{}, {}] }
        it 'applies corresponding items' do
          assert_equal(Set[
            schema.items[0],
          ], subject[0].jsi_schemas)
          assert_is_a(schema.items[0].jsi_schema_module, subject[0])
          refute_is_a(schema.items[0].jsi_schema_module, subject[1])
        end
      end
      describe 'additionalItems' do
        let(:schema_content) do
          YAML.load(<<~YAML
            items: [{}]
            additionalItems: {}
            YAML
          )
        end
        let(:instance) { [{}, {}] }
        it 'applies items, additionalItems' do
          assert_equal(Set[
            schema.items[0],
          ], subject[0].jsi_schemas)
          assert_equal(Set[
            schema.additionalItems,
          ], subject[1].jsi_schemas)
          assert_is_a(schema.items[0].jsi_schema_module, subject[0])
          assert_is_a(schema.additionalItems.jsi_schema_module, subject[1])
        end
      end
      describe 'additionalItems without items' do
        let(:schema_content) do
          YAML.load(<<~YAML
            additionalItems: {}
            YAML
          )
        end
        let(:instance) { [{}] }
        it 'applies none' do
          refute_is_a(schema.additionalItems.jsi_schema_module, subject[0])
        end
      end
    end
  end
  {
    draft06: JSI::JSONSchemaOrgDraft06,
    draft07: JSI::JSONSchemaOrgDraft07,
  }.each do |name, metaschema|
    describe "#{name} contains application" do
      let(:metaschema) { metaschema }
      describe 'contains valid' do
        let(:schema_content) do
          YAML.load(<<~YAML
            contains:
              type: array
            YAML
          )
        end
        let(:instance) { [{}, [], [], {}] }
        it 'applies' do
          assert_empty(subject[0].jsi_schemas)
          assert_equal(Set[
            schema.contains,
          ], subject[1].jsi_schemas)
          assert_equal(Set[
            schema.contains,
          ], subject[2].jsi_schemas)
          assert_empty(subject[3].jsi_schemas)
          refute_is_a(schema.contains.jsi_schema_module, subject[0])
          assert_is_a(schema.contains.jsi_schema_module, subject[1])
          assert_is_a(schema.contains.jsi_schema_module, subject[2])
          refute_is_a(schema.contains.jsi_schema_module, subject[3])
        end
      end
      describe 'contains invalid' do
        let(:schema_content) do
          YAML.load(<<~YAML
            contains:
              type: array
            YAML
          )
        end
        let(:instance) { [{}, {}] }
        it 'does not apply' do
          assert_empty(subject[0].jsi_schemas)
          assert_empty(subject[1].jsi_schemas)
          refute_is_a(schema.contains.jsi_schema_module, subject[0])
          refute_is_a(schema.contains.jsi_schema_module, subject[1])
        end
      end
    end
  end
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
    draft07: JSI::JSONSchemaOrgDraft07,
  }.each do |name, metaschema|
    describe "#{name} child properties, additionalProperties, patternProperties application" do
      let(:metaschema) { metaschema }
      describe 'properties' do
        let(:schema_content) do
          YAML.load(<<~YAML
            properties:
              foo: {}
            YAML
          )
        end
        let(:instance) { {'foo' => []} }
        it 'applies properties' do
          assert_equal(Set[
            schema.properties['foo'],
          ], subject['foo'].jsi_schemas)
          assert_is_a(schema.properties['foo'].jsi_schema_module, subject['foo'])
        end
      end
      describe 'additionalProperties' do
        let(:schema_content) do
          YAML.load(<<~YAML
            properties:
              foo: {}
            additionalProperties: {}
            YAML
          )
        end
        let(:instance) { {'foo' => [], 'bar' => []} }
        it 'applies properties, additionalProperties' do
          assert_equal(Set[
            schema.properties['foo'],
          ], subject['foo'].jsi_schemas)
          assert_equal(Set[
            schema.additionalProperties,
          ], subject['bar'].jsi_schemas)
          assert_is_a(schema.properties['foo'].jsi_schema_module, subject['foo'])
          assert_is_a(schema.additionalProperties.jsi_schema_module, subject['bar'])
        end
      end
      describe 'additionalProperties without properties' do
        let(:schema_content) do
          YAML.load(<<~YAML
            additionalProperties: {}
            YAML
          )
        end
        let(:instance) { {'foo' => []} }
        it 'applies additionalProperties' do
          assert_equal(Set[
            schema.additionalProperties,
          ], subject['foo'].jsi_schemas)
          assert_is_a(schema.additionalProperties.jsi_schema_module, subject['foo'])
        end
      end
      describe 'additionalProperties without properties' do
        let(:schema_content) do
          YAML.load(<<~YAML
            additionalProperties: {}
            YAML
          )
        end
        let(:instance) { {'foo' => []} }
        it 'applies additionalProperties' do
          assert_equal(Set[
            schema.additionalProperties,
          ], subject['foo'].jsi_schemas)
          assert_is_a(schema.additionalProperties.jsi_schema_module, subject['foo'])
        end
      end
      describe 'properties, additionalProperties, patternProperties' do
        let(:schema_content) do
          YAML.load(<<~YAML
            properties:
              foo:
                title: foo
              baz:
                title: baz
            patternProperties:
              "^b":
                title: 'b*'
            additionalProperties:
              title: additional
            YAML
          )
        end
        let(:instance) do
          YAML.load(<<~YAML
            foo: {}
            bar: {}
            baz: {}
            qux: {}
            YAML
          )
        end
        it 'applies those applicable' do
          assert_equal(Set[
            schema.properties['foo'],
          ], subject['foo'].jsi_schemas)
          assert_equal(Set[
            schema.patternProperties['^b'],
          ], subject['bar'].jsi_schemas)
          assert_equal(Set[
            schema.properties['baz'],
            schema.patternProperties['^b'],
          ], subject['baz'].jsi_schemas)
          assert_equal(Set[
            schema.additionalProperties,
          ], subject['qux'].jsi_schemas)

          assert_is_a(schema.properties['foo'].jsi_schema_module, subject['foo'])
          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['foo'])
          refute_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['foo'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['foo'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['bar'])
          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['bar'])
          assert_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['bar'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['bar'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['baz'])
          assert_is_a(schema.properties['baz'].jsi_schema_module, subject['baz'])
          assert_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['baz'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['baz'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['qux'])
          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['qux'])
          refute_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['qux'])
          assert_is_a(schema.additionalProperties.jsi_schema_module, subject['qux'])
        end
      end
    end
  end
end
