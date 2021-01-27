require_relative 'test_helper'

describe 'JSI Schema child application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
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
end
