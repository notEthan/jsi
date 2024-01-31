require_relative 'test_helper'

describe 'JSI Schema child application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe("#{name} child application aborted by $ref") do
      let(:metaschema) { metaschema }

      describe("array instance") do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              a:
                items: [{}]
            $ref: "#/definitions/a"
            items: [{}]
            additionalItems: {}
            contains: {}
            YAML
          )
        end
        let(:instance) { [{}, {}] }

        it("applies no $ref siblings") do
          assert_schemas([schema.definitions['a'].items[0]], subject[0])
          assert_schemas([], subject[1])
          refute_schema(schema.items[0], subject[0])
          refute_schema(schema.items[0], subject[1])
          refute_schema(schema.additionalItems, subject[0])
          refute_schema(schema.additionalItems, subject[1])
          if schema['contains'].jsi_is_schema? # skip draft04
            refute_schema(schema.contains, subject[0])
            refute_schema(schema.contains, subject[1])
          end
        end
      end

      describe("hash/object instance") do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              a:
                properties:
                  a: {}
            $ref: "#/definitions/a"
            properties: {a: {}}
            patternProperties: {a: {}}
            additionalProperties: {}
            YAML
          )
        end
        let(:instance) { {"a" => {}, "b" => {}} }

        it("applies no $ref siblings") do
          assert_schemas([schema.definitions['a'].properties['a']], subject['a'])
          assert_schemas([], subject['b'])
          refute_schema(schema.properties['a'], subject['a'])
          refute_schema(schema.properties['a'], subject['b'])
          refute_schema(schema.patternProperties['a'], subject['a'])
          refute_schema(schema.patternProperties['a'], subject['b'])
          refute_schema(schema.additionalProperties, subject['a'])
          refute_schema(schema.additionalProperties, subject['b'])
        end
      end
    end
  end

  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
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
        it('array instance: applies items') do
          assert_schemas([
            schema.items,
          ], subject[0])
        end
        describe('hash/object instance') do
          let(:instance) { {0 => {}, '0' => {}, 'x' => {}} }
          it('does not apply items') do
            refute_schema(schema.items, subject[0])   # not officially supported, integer key not in JSON data model
            refute_schema(schema.items, subject['0'])
            refute_schema(schema.items, subject['x'])
          end
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
        it('array instance: applies corresponding items') do
          assert_schemas([
            schema.items[0],
          ], subject[0])
          refute_is_a(schema.items[0].jsi_schema_module, subject[1])
        end
        describe('hash/object instance') do
          let(:instance) { {0 => {}, '0' => {}, 'x' => {}} }
          it('does not apply items') do
            refute_schema(schema.items[0], subject[0])
            refute_schema(schema.items[0], subject['0'])
            refute_schema(schema.items[0], subject['x'])
          end
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
        it('array instance: applies items, additionalItems') do
          assert_schemas([
            schema.items[0],
          ], subject[0])
          assert_schemas([
            schema.additionalItems,
          ], subject[1])
        end
        describe('hash/object instance') do
          let(:instance) { {0 => {}, '0' => {}, 'x' => {}} }
          it('does not apply items or additionalItems') do
            refute_schema(schema.items[0], subject[0])
            refute_schema(schema.items[0], subject['0'])
            refute_schema(schema.items[0], subject['x'])
            refute_schema(schema.additionalItems, subject[0])
            refute_schema(schema.additionalItems, subject['0'])
            refute_schema(schema.additionalItems, subject['x'])
          end
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
        it('array instance: applies none') do
          refute_is_a(schema.additionalItems.jsi_schema_module, subject[0])
        end
        describe('hash/object instance') do
          let(:instance) { {0 => {}, '0' => {}} }
          it('does not apply') do
            refute_schema(schema.additionalItems, subject[0])
            refute_schema(schema.additionalItems, subject['0'])
          end
        end
      end
    end
  end
  {
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
    draft202012: JSI::JSONSchemaDraft202012,
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
        it('array instance: applies') do
          assert_schemas([], subject[0])
          assert_schemas([
            schema.contains,
          ], subject[1])
          assert_schemas([
            schema.contains,
          ], subject[2])
          assert_schemas([], subject[3])
          refute_is_a(schema.contains.jsi_schema_module, subject[0])
          refute_is_a(schema.contains.jsi_schema_module, subject[3])
        end
        describe('hash/object instance') do
          let(:instance) { {0 => {}, '0' => {}, 1 => [], '1' => []} }
          it('does not apply contains') do
            refute_schema(schema.contains, subject[0])
            refute_schema(schema.contains, subject['0'])
            refute_schema(schema.contains, subject[1])
            refute_schema(schema.contains, subject['1'])
          end
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
        it 'applies' do
          assert_schemas([
            schema.contains,
          ], subject[0])
          assert_schemas([
            schema.contains,
          ], subject[1])
        end
      end
    end
  end
  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
    draft202012: JSI::JSONSchemaDraft202012,
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
        it('hash/object instance: applies properties') do
          assert_schemas([
            schema.properties['foo'],
          ], subject['foo'])
        end
        describe('array instance') do
          let(:schema_content) do
            YAML.load(<<~YAML
              properties:
                0: {}
              YAML
            )
          end
          let(:instance) { [{}] }
          it('does not apply properties') do
            refute_schema(schema.properties[0], subject[0])
          end
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
        it('hash/object instance: applies properties, additionalProperties') do
          assert_schemas([
            schema.properties['foo'],
          ], subject['foo'])
          assert_schemas([
            schema.additionalProperties,
          ], subject['bar'])
        end
        describe('array instance') do
          let(:schema_content) do
            YAML.load(<<~YAML
              properties:
                0: {}
              additionalProperties: {}
              YAML
            )
          end
          let(:instance) { [{}, {}] }
          it('does not apply properties or additionalProperties') do
            refute_schema(schema.properties[0], subject[0])
            refute_schema(schema.additionalProperties, subject[0])
            refute_schema(schema.additionalProperties, subject[1])
          end
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
        it('hash/object instance: applies additionalProperties') do
          assert_schemas([
            schema.additionalProperties,
          ], subject['foo'])
        end
        describe('array instance') do
          let(:schema_content) do
            YAML.load(<<~YAML
              additionalProperties: {}
              YAML
            )
          end
          let(:instance) { [{}] }
          it('does not apply additionalProperties') do
            refute_schema(schema.additionalProperties, subject[0])
          end
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
        it('hash/object instance: applies those applicable') do
          assert_schemas([
            schema.properties['foo'],
          ], subject['foo'])
          assert_schemas([
            schema.patternProperties['^b'],
          ], subject['bar'])
          assert_schemas([
            schema.properties['baz'],
            schema.patternProperties['^b'],
          ], subject['baz'])
          assert_schemas([
            schema.additionalProperties,
          ], subject['qux'])

          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['foo'])
          refute_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['foo'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['foo'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['bar'])
          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['bar'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['bar'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['baz'])
          refute_is_a(schema.additionalProperties.jsi_schema_module, subject['baz'])

          refute_is_a(schema.properties['foo'].jsi_schema_module, subject['qux'])
          refute_is_a(schema.properties['baz'].jsi_schema_module, subject['qux'])
          refute_is_a(schema.patternProperties['^b'].jsi_schema_module, subject['qux'])
        end
        describe('array instance') do
          let(:schema_content) do
            YAML.load(<<~YAML
              properties:
                0:
                  title: 0
                2:
                  title: 2
              patternProperties:
                "[12]":
                  title: '[12]'
              additionalProperties:
                title: additional
              YAML
            )
          end
          let(:instance) { [{}, {}, {}, {}] }
          it('does not apply') do
            refute_schema(schema.properties[0], subject[0])
            refute_schema(schema.properties[2], subject[0])
            refute_schema(schema.patternProperties['[12]'], subject[0])
            refute_schema(schema.additionalProperties, subject[0])
            refute_schema(schema.properties[0], subject[1])
            refute_schema(schema.properties[2], subject[1])
            refute_schema(schema.patternProperties['[12]'], subject[1])
            refute_schema(schema.additionalProperties, subject[1])
            refute_schema(schema.properties[0], subject[2])
            refute_schema(schema.properties[2], subject[2])
            refute_schema(schema.patternProperties['[12]'], subject[2])
            refute_schema(schema.additionalProperties, subject[2])
            refute_schema(schema.properties[0], subject[3])
            refute_schema(schema.properties[2], subject[3])
            refute_schema(schema.patternProperties['[12]'], subject[3])
            refute_schema(schema.additionalProperties, subject[3])
          end
        end
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
