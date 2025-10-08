require_relative 'test_helper'

describe("resource URIs") do
  describe("override #jsi_each_resource_uri_compute") do
    it("registers and finds by resource URI overridden to include $self property") do
      registry = JSI::Registry.new
      schema = JSI::JSONSchemaDraft07.new_schema({"patternProperties": {"^\\w": {"$ref": "http://json-schema.org/draft-07/schema#"}}})
      schema.jsi_schema_module_exec do
        def jsi_each_resource_uri_compute
          super
          self_uri = jsi_node_content['$self']
          if self_uri
            yield jsi_base_uri ? jsi_base_uri.join(self_uri) : JSI::URI[self_uri]
          end
        end
      end
      jsi = schema.new_jsi({"$self" => "tag:c8dd/root", "x" => {"$id" => "xrel"}}, registry: registry, register: true)
      assert_equal(jsi, registry.find('tag:c8dd/root'))
      assert_equal(jsi['x'], registry.find('tag:c8dd/xrel'))
      jsi = schema.new_jsi({"$self" => "rel", "x" => {"$id" => "xrel"}}, root_uri: 'tag:c8de/base', registry: registry, register: true)
      assert_equal(jsi, registry.find('tag:c8de/base'))
      assert_equal(jsi, registry.find('tag:c8de/rel'))
      assert_equal(jsi['x'], registry.find('tag:c8de/xrel'))
    end
  end
end

$test_report_file_loaded[__FILE__]
