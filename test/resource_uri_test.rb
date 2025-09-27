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

describe("resource URIs from root, base, $id") do
  root_abs_uri_s = 'http://jsi/root'
  root_abs_id = 'http://jsi/root_id'
  base_abs_uri_s = 'http://jsi/base'
  root_abs_uri = JSI::URI[root_abs_uri_s]
  base_abs_uri = JSI::URI[base_abs_uri_s]
  root_rel_id = 'root_id'
  desc_abs_id = 'http://jsi/desc_id'
  desc_rel_id = 'desc_id'

  test_instance_schema = JSI::JSONSchemaDraft07.new_schema({
    "properties": {
      "definitions": {
        "additionalProperties": {"$ref": "http://json-schema.org/draft-07/schema"},
      },
    },
  })
  content = proc do |id, desc_id|
    JSI::Util.deep_stringify_symbol_keys((id ? {"$id": id} : {}).merge({
      "definitions": {
        "desc": desc_id ? {"$id": desc_id} : {},
      },
    }))
  end
  new_jsi = proc do |id, desc_id, kw|
    test_instance_schema.new_jsi(content[id, desc_id], **kw)
  end
  new_schema = proc do |id, desc_id, kw|
    JSI::JSONSchemaDraft07.new_schema(content[id, desc_id], **kw)
  end

  cases = [
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [],                          exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: nil,            base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id],               exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri_s, base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: nil},            root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri_s}, root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: nil,         desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_rel_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: nil,         new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [],            line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_rel_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_jsi,              exp_root_resource_uris: [root_abs_uri],              exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
    {kw: {root_uri: root_abs_uri,   base_uri: base_abs_uri},   root_id: root_abs_id, desc_id: desc_abs_id, new: new_schema,           exp_root_resource_uris: [root_abs_id, root_abs_uri], exp_desc_resource_uris: [desc_abs_id], line: __LINE__},
  ]

  cases.map(&:values).each do |kw, root_id, desc_id, new, exp_root_resource_uris, exp_desc_resource_uris, line|
    it("case #{Pathname.new(__FILE__).relative_path_from(JSI::ROOT_PATH)}:#{line}") do
      instance = new[root_id, desc_id, kw]
      assert_uris(exp_root_resource_uris, instance.jsi_resource_uris)
      desc = instance.definitions['desc']
      assert_uris(exp_desc_resource_uris, desc.jsi_resource_uris)
    end
  end
end

$test_report_file_loaded[__FILE__]
