require_relative 'test_helper'

describe 'JSI Schema child application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }
  {
    draft04: JSI::JSONSchemaOrgDraft04,
    draft06: JSI::JSONSchemaOrgDraft06,
  }.each do |name, metaschema|
    describe "#{name} child items application" do
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
    end
  end
end
