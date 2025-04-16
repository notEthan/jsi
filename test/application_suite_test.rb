require_relative('test_helper')

ApplicationTestSet = JSI.new_schema_module(YAML.safe_load(JSI::TEST_RESOURCES_PATH.join('application_test_set.schema.yml').read))

describe("application") do
  path = JSI::TEST_RESOURCES_PATH.join(JSI::TEST_RESOURCES_PATH.join('application_tests'))
  subpaths = Dir.chdir(path) { Dir['**/*.yml'] }
  subpaths.each do |subpath|
    application_test_set = ApplicationTestSet.new_jsi(YAML.safe_load(path.join(subpath).read))

    application_test_set.each do |testitem|
      testitem.dialects.each do |dialect_id|
        schema = JSI.schema_registry.find(dialect_id).new_schema(testitem.jsi_node_content['schema'])

        testitem.tests(use_default: true).each do |test|
          test_descr = [
            subpath,
            testitem.description,
            JSI::URI[dialect_id].path, # the full uri is a bit long/redundant for test description
            test.description || JSON.generate(test.instance),
          ].freeze

          jsi = schema.new_jsi(test.jsi_node_content['instance'])

          it([*test_descr, 'validation'].join(' : ')) do
            assert_consistent_jsi_descendent_errors(jsi)
          end

          test.schemas.each do |instance_pointer, schema_refs|
            jsi_desc = jsi / instance_pointer
            expected_schemas = JSI::SchemaSet.new(schema_refs) do |ref_uri|
              ref = JSI::Schema::Ref.new(ref_uri, ref_schema: schema)
              ref.deref_schema
            end

            it([*test_descr, instance_pointer].join(' : ')) do
              assert_equal(expected_schemas, jsi_desc.jsi_schemas, proc do
                {
                  expected_schema_refs: schema_refs.to_a,
                  actual_schema_refs: jsi_desc.jsi_schemas.map { |s| (s.schema_uri || s.jsi_ptr.uri).to_s },
                  test_schema: schema,
                  instance_document: test.jsi_node_content['instance'],
                  instance_pointer: instance_pointer,
                }.pretty_inspect.chomp
              end)
            end
          end
        end
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
