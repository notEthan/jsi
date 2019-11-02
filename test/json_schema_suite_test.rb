require_relative 'test_helper'

JSONSchemaTestSchema = JSI::Schema.new(JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').read))

describe 'JSON Schema Test Suite' do
  describe 'validity' do
    drafts = [
      {name: 'draft4', metaschema: JSI::JSONSchemaOrgDraft04.schema},
      {name: 'draft6', metaschema: JSI::JSONSchemaOrgDraft06.schema},
    ]
    drafts.each do |name: , metaschema: |
      describe(name) do
        draft_dir = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests').join(name)
        JSI::Util.ycomb do |rec|
          proc do |path|
            if path.directory?
              path.children.each(&rec)
            elsif path.file? && path.to_s =~ /\.json\z/
              JSONSchemaTestSchema.new_jsi(::JSON.parse(path.read)).map do |tests_desc|
                describe(tests_desc.description) do
                  let(:schema) { metaschema.new_jsi(JSI::Typelike.as_json(tests_desc['schema'])) }
                  tests_desc.tests.each do |test|
                    describe(test.description) do
                      let(:jsi) { schema.new_jsi(JSI::Typelike.as_json(test.data)) }
                      it(test.valid ? 'is valid' : 'is invalid') do
                        if test.valid != jsi.jsi_valid?
                          errors = jsi.jsi_validate
                          assert(false, {
                            valid: test.valid,
                            data: test.data,
                            schema: schema,
                            errors: errors,
                          }.pretty_inspect)
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end.call(draft_dir)
      end
    end
  end
end
