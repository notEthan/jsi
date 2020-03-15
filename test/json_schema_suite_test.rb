require_relative 'test_helper'

JSONSchemaTestSchema = JSI::Schema.new(JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').read))

JSI::Util.ycomb do |rec|
  proc do |subpath|
    path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/remotes').join(*subpath)

    if path.directory?
      path.children(with_directory = false).each { |c| rec.call(subpath + [c.to_s]) }
    elsif path.file? && path.to_s =~ /\.json\z/
      remote_content = ::JSON.parse(path.read)
      id = File.join('http://localhost:1234/', *subpath)
      if subpath == ['subSchemas.json']
        subSchemas_schema = JSI::Schema.new({'additionalProperties' => {'$ref' => JSI::Schema.default_metaschema.id}})
        subSchemas = subSchemas_schema.new_jsi(remote_content)
        JSI.schema_registry.register(subSchemas, schema_id: id)
      else
        JSI::Schema.new(remote_content, schema_id: id)
      end
    end
  end
end.call([])

describe 'JSON Schema Test Suite' do
  describe 'validity' do
    drafts = [
      {name: 'draft4', metaschema: JSI::JSONSchemaOrgDraft04.schema},
      {name: 'draft6', metaschema: JSI::JSONSchemaOrgDraft06.schema},
    ]
    drafts.each do |name: , metaschema: |
      JSI::Util.ycomb do |rec|
        proc do |subpath|
          path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests').join(*subpath)
          if path.directory?
            path.children(with_directory = false).each { |c| rec.call(subpath + [c]) }
          elsif path.file? && path.to_s =~ /\.json\z/
            describe(subpath.join('/')) do
              JSONSchemaTestSchema.new_jsi(::JSON.parse(path.read)).map do |tests_desc|
                describe(tests_desc.description) do
                  let(:schema) do
                    begin
                      metaschema.new_jsi(JSI::Typelike.as_json(tests_desc['schema'])).tap(&:jsi_register_schema)
                    rescue JSI::Schema::IdHasFragment
                      skip('unsupported id with fragment')
                    end
                  end
                  tests_desc.tests.each do |test|
                    describe(test.description) do
                      let(:jsi) { schema.new_jsi(JSI::Typelike.as_json(test.data)) }
                      it(test.valid ? 'is valid' : 'is invalid') do
                        result = jsi.jsi_validate
                        if test.valid != result.valid?
                          if !test.valid && schema['format']
                            skip('format validation')
                          else
                            assert(false, {
                              valid: test.valid,
                              data: test.data,
                              schema: schema,
                              result: result,
                            }.pretty_inspect)
                          end
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
