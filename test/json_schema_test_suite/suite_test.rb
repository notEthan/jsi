require_relative '../test_helper'

$test_report_time["json_schema_test_suite/suite_test loading"]

test_schema_path = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/test-schema.json')
JSONSchemaTestSchema = JSI::JSONSchemaDraft07.new_schema(JSON.parse(test_schema_path.open('r:UTF-8').read))
$test_report_time["JSONSchemaTestSchema set up"]

JSTS_REGISTRIES = Hash.new do |h, metaschema|
  jsts_schema_registry = JSI.schema_registry.dup

  Dir.chdir(JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/remotes')) do
    Dir.glob('**/*.json').each do |subpath|
      remote_content = JSON.parse(File.open(subpath, 'r:UTF-8', &:read), freeze: true)
      uri = File.join('http://localhost:1234/', subpath)
      jsts_schema_registry.autoload_uri(uri) do |schema_registry: |
        if subpath == 'subSchemas.json' && !remote_content.key?('definitions') # TODO rm
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

  h[metaschema] = jsts_schema_registry
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
          base = JSI::TEST_RESOURCES_PATH.join('JSON-Schema-Test-Suite/tests')
          subpaths = Dir.chdir(base) { Dir.glob(File.join(name, '**/*.json')) }
          subpaths.each do |subpath|
            path = base.join(subpath)
            describe(subpath) do
              begin
                tests_desc_object = JSON.parse(path.open('r:UTF-8', &:read), freeze: true)
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
                desc_schema_registry = JSTS_REGISTRIES[metaschema].dup
                desc_schema = JSI.new_schema(tests_desc.jsi_instance['schema'],
                  schema_registry: desc_schema_registry,
                  default_metaschema: metaschema,
                )

                bootstrap_schema_registry = JSTS_REGISTRIES[metaschema].dup
                bootstrap_schema_class = desc_schema.dialect.bootstrap_schema_class
                desc_bootstrap_schema = bootstrap_schema_class.new(
                  tests_desc.jsi_instance['schema'],
                  jsi_schema_registry: bootstrap_schema_registry,
                )
                bootstrap_schema_registry.register(desc_bootstrap_schema)

                describe(tests_desc.description) do
                  let(:schema) { desc_schema }
                  let(:bootstrap_schema) { desc_bootstrap_schema }
                  let(:optional) { subpath.split('/').include?('optional') }

                  if desc_schema.is_a?(JSI::Base)
                    it("collects subschemas consistently with the metaschema") do
                      metaschema_described_subschemas = Set.new(schema.jsi_each_descendent_node.select(&:jsi_is_schema?))
                      element_described_subschemas = Set.new(schema.jsi_each_descendent_schema)

                      assert_equal(metaschema_described_subschemas, element_described_subschemas)
                    end
                  end

                  tests_desc.tests.each do |test|
                      it(test.description) do
                        begin
                          jsi = schema.new_jsi(test.jsi_instance['data'], schema_registry: nil)
                        rescue JSI::ResolutionError => e
                          raise unless e.uri.to_s == 'https://json-schema.org/draft/2019-09/schema'
                          skip("unsupported URI: #{e.uri}")
                        end

                        result = jsi.jsi_validate
                        assert_equal(result.valid?, jsi.jsi_valid?)

                        assert_equal(result.valid?, bootstrap_schema.instance_valid?(test.jsi_instance['data']))

                        if !test.valid
                          result.each_validation_error do |result_error|
                            # since the test data instance has an error at result_error.instance_ptr,
                            # validation of the JSI descendent at that ptr should include that error,
                            # as well as errors of its descendents.

                            errors_below_instance_ptr = result.each_validation_error.select do |e|
                              result_error.instance_ptr.ancestor_of?(e.instance_ptr)
                            end.to_set

                            descendent = jsi.jsi_descendent_node(result_error.instance_ptr)
                            descendent_errors = descendent.jsi_validate.each_validation_error.to_set

                            assert_equal(errors_below_instance_ptr, descendent_errors)
                          end
                        end

                        if test.valid != result.valid?
                          unsupported_keywords = [
                            'format',
                            'contentMediaType',
                            'contentEncoding',
                          ].select { |kw| schema.keyword?(kw) }
                          if unsupported_keywords.any? && optional
                            skip("unsupported validation keywords: #{unsupported_keywords.join(' ')}")
                          end

                          regexs = schema.jsi_each_descendent_node.select do |node|
                            node.jsi_schemas.any? { |s| s.keyword?('format') && s['format'] == 'regex' }
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
