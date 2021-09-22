require_relative '../test_helper'

JSONSchemaTestSchema = JSI.new_schema(JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').open('r:UTF-8').read))

JSI::Util.ycomb do |rec|
  proc do |subpath|
    path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/remotes').join(*subpath)

    if path.directory?
      with_directory = false
      path.children(with_directory).each { |c| rec.call(subpath + [c.to_s]) }
    elsif path.file? && path.to_s =~ /\.json\z/
      remote_content = ::JSON.parse(path.open('r:UTF-8').read)
      uri = File.join('http://localhost:1234/', *subpath)
      JSI.schema_registry.autoload_uri(uri) do
        if subpath == ['subSchemas.json']
          subSchemas_schema = JSI.new_schema({
            '$schema' => 'http://json-schema.org/draft-07/schema',
            'additionalProperties' => {'$ref' => 'http://json-schema.org/draft-07/schema'},
          })
          subSchemas_schema.new_jsi(remote_content, uri: uri)
        else
          JSI.new_schema(remote_content, uri: uri, default_metaschema: JSI::JSONSchemaOrgDraft07)
        end
      end
    end
  end
end.call([])

describe 'JSON Schema Test Suite' do
  describe 'validity' do
    drafts = [
      {name: 'draft4', metaschema: JSI::JSONSchemaOrgDraft04.schema},
      {name: 'draft6', metaschema: JSI::JSONSchemaOrgDraft06.schema},
      {name: 'draft7', metaschema: JSI::JSONSchemaOrgDraft07.schema},
    ]
    drafts.each do |draft|
      name = draft[:name]
      metaschema = draft[:metaschema]
      JSI::Util.ycomb do |rec|
        proc do |subpath|
          path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests').join(*subpath)
          if path.directory?
            with_directory = false
            path.children(with_directory).each { |c| rec.call(subpath + [c.to_s]) }
          elsif path.file? && path.to_s =~ /\.json\z/
            describe(subpath.join('/')) do
              begin
                tests_desc_object = ::JSON.parse(path.open('r:UTF-8').read)
              rescue JSON::ParserError => e
                # :nocov:
                # known json/pure issue https://github.com/flori/json/pull/483
                raise unless e.message =~ /Encoding::CompatibilityError/
                warn("JSON Schema Test Suite skipping #{path}")
                warn(e)
                tests_desc_object = []
                # :nocov:
              end
              JSONSchemaTestSchema.new_jsi(tests_desc_object).map do |tests_desc|
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
                          unsupported_keywords = [
                            'format',
                            'contentMediaType',
                            'contentEncoding',
                          ].select { |kw| schema.respond_to?(:to_hash) && schema.key?(kw) }
                          if unsupported_keywords.any?
                            skip("unsupported keywords: #{unsupported_keywords.join(' ')}")
                          end

                          regexs = schema.jsi_each_descendent_node.select do |node|
                            node.jsi_schemas.any? { |s| s['format'] == 'regex' }
                          end.map(&:jsi_node_content)
                          schema.jsi_each_descendent_node.each do |node|
                            if node.is_a?(JSI::Schema) && node.respond_to?(:to_hash) && node.key?('patternProperties')
                              regexs += node.patternProperties.keys
                            end
                          end
                          regexs.each do |regex|
                            if regex =~ /\\[dDwWsS]/
                              skip("unsupported unicode character range")
                            end
                          end

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