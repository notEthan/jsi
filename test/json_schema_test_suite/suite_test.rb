require_relative '../test_helper'

$test_report_time["json_schema_test_suite/suite_test loading"]

JSONSchemaTestSchema = JSI.new_schema(JSON.parse(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json').open('r:UTF-8', &:read)))
$test_report_time["JSONSchemaTestSchema set up"]

JSTS_REGISTRIES = Hash.new do |h, metaschema|
  schema_registry = JSI.schema_registry.dup

  Dir.chdir(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/remotes')) do
    Dir.glob('**/*.json').each do |subpath|
      remote_content = ::JSON.parse(File.open(subpath, 'r:UTF-8', &:read))
      uri = File.join('http://localhost:1234/', subpath)
      schema_registry.autoload_uri(uri) do
        if subpath == 'subSchemas.json'
          subSchemas_schema = JSI.new_schema({
            '$schema' => 'http://json-schema.org/draft-07/schema',
            'additionalProperties' => {'$ref' => 'http://json-schema.org/draft-07/schema'},
          })
          subSchemas_schema.new_jsi(remote_content,
            uri: uri,
            schema_registry: schema_registry,
          )
        else
          JSI.new_schema(remote_content,
            uri: uri,
            default_metaschema: metaschema,
            schema_registry: schema_registry,
          )
        end
      end
    end
  end
  $test_report_time["remotes set up"]

  h[metaschema] = schema_registry
end

describe 'JSON Schema Test Suite' do
    drafts = [
      {name: 'draft4', metaschema: JSI::JSONSchemaDraft04.schema},
      {name: 'draft6', metaschema: JSI::JSONSchemaDraft06.schema},
      {name: 'draft7', metaschema: JSI::JSONSchemaDraft07.schema},
    ]
    drafts.each do |draft|
      name = draft[:name]
      metaschema = draft[:metaschema]
      desc_schema_registry = JSTS_REGISTRIES[metaschema]

          base = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests')
          subpaths = Dir.chdir(base) { Dir.glob(File.join(name, '**/*.json')) }
          subpaths.each do |subpath|
            path = base.join(subpath)
            describe(subpath) do
              begin
                tests_desc_object = ::JSON.parse(path.open('r:UTF-8', &:read))
              rescue JSON::ParserError => e
                # :nocov:
                # known json/pure issue https://github.com/flori/json/pull/483
                raise unless e.message =~ /Encoding::CompatibilityError/
                warn("JSON Schema Test Suite skipping #{path}")
                warn(e)
                tests_desc_object = []
                # :nocov:
              end
              JSONSchemaTestSchema.new_jsi(tests_desc_object).each do |tests_desc|
                desc_schema = metaschema.new_schema(tests_desc.jsi_instance['schema'], schema_registry: desc_schema_registry)

                describe(tests_desc.description) do
                  let(:schema_registry) { desc_schema_registry }
                  let(:schema) { desc_schema }

                  tests_desc.tests.each do |test|
                      it(test.description) do
                        jsi = schema.new_jsi(test.jsi_instance['data'], schema_registry: schema_registry)
                        result = jsi.jsi_validate
                        assert_equal(result.valid?, jsi.jsi_valid?)
                        if test.valid != result.valid?
                          unsupported_keywords = [
                            'format',
                            'contentMediaType',
                            'contentEncoding',
                          ].select { |kw| schema.keyword?(kw) }
                          if unsupported_keywords.any?
                            skip("unsupported validation keywords: #{unsupported_keywords.join(' ')}")
                          end

                          regexs = schema.jsi_each_descendent_node.select do |node|
                            node.jsi_schemas.any? { |s| s['format'] == 'regex' }
                          end.map(&:jsi_node_content)
                          schema.jsi_each_descendent_node do |node|
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
      $test_report_time["#{name} tests set up"]
    end
end

$test_report_file_loaded[__FILE__]
