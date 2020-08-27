require_relative 'test_helper'

JSONSchemaTestSchema = JSI.new_schema(JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').read))

describe 'JSON Schema Test Suite' do
  describe 'validity' do
    drafts = [
    ]
    drafts.each do |name: , metaschema: |
      JSI::Util.ycomb do |rec|
        proc do |subpath|
          path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests').join(*subpath)
          if path.directory?
            path.children(with_directory = false).each { |c| rec.call(subpath + [c.to_s]) }
          elsif path.file? && path.to_s =~ /\.json\z/
            describe(subpath.join('/')) do
              JSONSchemaTestSchema.new_jsi(::JSON.parse(path.read)).map do |tests_desc|
                describe(tests_desc.description) do
                  around do |test|
                    registry_before = JSI.schema_registry.dup
                    test.call
                    JSI.send(:instance_variable_set, :@schema_registry, registry_before)
                  end
                  let(:schema) do
                    metaschema.new_schema(tests_desc.jsi_instance['schema'])
                  end
                  tests_desc.tests.each do |test|
                    describe(test.description) do
                      let(:jsi) { schema.new_jsi(test.jsi_instance['data']) }
                      it(test.valid ? 'is valid' : 'is invalid') do
                        result = jsi.jsi_validate
                        assert_equal(result.valid?, jsi.jsi_valid?)
                        if test.valid != result.valid?
                          # :nocov:
                          assert(false, [
                            test.valid ? "expected valid, got errors: " : "expected errors, got valid: ",
                            'file: ' + path.to_s,
                            'test data: ' + test.data.pretty_inspect.chomp,
                            'test schema: ' + schema.pretty_inspect.chomp,
                            'validation result: ' + result.pretty_inspect.chomp,
                          ].join("\n"))
                          # :nocov:
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end.call([name])
    end
  end
end
