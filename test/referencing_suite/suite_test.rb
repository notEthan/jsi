require_relative '../test_helper'

$test_report_time["referencing suite_test loading"]

describe("JSON Referencing Test Suite") do
  drafts = [
    {name: '04', metaschema: JSI::JSONSchemaDraft04.schema},
    {name: '06', metaschema: JSI::JSONSchemaDraft06.schema},
    {name: '07', metaschema: JSI::JSONSchemaDraft07.schema},
  ]
  drafts.each do |draft|
    name = draft[:name]
    metaschema = draft[:metaschema]
    base = JSI::TEST_RESOURCES_PATH.join("referencing-suite/tests")
    subpaths = Dir.chdir(base) { Dir.glob(File.join("json-schema-draft-#{name}", "**/*.json")) }
    subpaths.each do |subpath|
      path = base.join(subpath)
      describe(subpath) do
        ref_tests = JSON.parse(path.open('r:UTF-8', &:read))
        desc_schema_registry = JSI.schema_registry.dup
        ref_tests['registry'].each_key do |uri|
          schema_content = ref_tests['registry'][uri]
          auri = JSI::Util.uri(uri)
          auri = auri.merge(fragment: nil) if auri.fragment == ''
          metaschema.new_schema(schema_content, uri: auri, schema_registry: desc_schema_registry)
        end

        let(:schema_registry) { desc_schema_registry }

        ref_tests['tests'].each do |init_test|
          describe("resolving #{init_test['ref']}") do
            let(:init_test) { init_test }

            it("resolves") do
              base_uri = init_test['base_uri']
              curr_test = init_test
              while curr_test
                ref_uri = base_uri ? JSI::Util.uri(base_uri).join(curr_test['ref']).freeze : curr_test['ref']
                ref = JSI::Schema::Ref.new(ref_uri, schema_registry: schema_registry)
                if curr_test['error']
                  raise(Bug) if curr_test['then']
                  begin
                    resolved_schema = ref.deref_schema
                    if resolved_schema['$ref']
                      skip("unsupported: id is ignored when $ref is a sibling")
                    end
                    assert(false, [
                      "expected resolution to error",
                      "test: #{curr_test.pretty_inspect.chomp}",
                      "with base URI: #{base_uri.inspect}",
                      "resolved to: #{resolved_schema.pretty_inspect.chomp}",
                    ].join("\n"))
                  rescue JSI::SchemaRegistry::ResourceNotFound, JSI::Schema::ReferenceError
                  end
                else
                  resolved_schema = ref.deref_schema
                  assert_equal(curr_test['target'], resolved_schema.jsi_node_content)
                  base_uri = resolved_schema.jsi_resource_ancestor_uri
                end
                curr_test = curr_test['then']
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
