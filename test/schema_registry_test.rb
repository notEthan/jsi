require_relative 'test_helper'

describe 'JSI::SchemaRegistry' do
  let(:schema_registry) { JSI::DEFAULT_SCHEMA_REGISTRY.dup }

  describe 'operation' do
    it 'registers a schema and finds it' do
      uri = 'http://jsi/schema_registry/iepm'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      })
      schema_registry.register(resource)
      assert_equal(resource, schema_registry.find(uri))
    end

    it 'does not find a schema that is not registered' do
      uri = 'http://jsi/schema_registry/55e6'
      e = assert_raises(JSI::SchemaRegistry::ResourceNotFound) { schema_registry.find(uri) }
      assert_uri(uri, e.uri)
    end

    it 'registers a nonschema and finds it' do
      uri = 'http://jsi/schema_registry/d7eu'
      resource = JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}, uri: uri)
      schema_registry.register(resource)
      assert_equal(resource, schema_registry.find(uri))
    end

    it 'registers a nonschema with no resource URIs' do
      resource = JSI::JSONSchemaDraft07.new_schema({}).new_jsi({})
      schema_registry.register(resource)
    end

    it "registers something that's not a schema below document root with a URI" do
      uri = 'http://jsi/schema_registry/skw7'
      resource = JSI::JSONSchemaDraft07.new_schema({'items' => {}}).new_jsi([{}], uri: uri)
      err = assert_raises(ArgumentError) do
        schema_registry.register(resource[0])
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers something that's not a schema below document root without a URI" do
      resource = JSI::JSONSchemaDraft07.new_schema({'items' => {}}).new_jsi([{}])
      err = assert_raises(ArgumentError) do
        schema_registry.register(resource[0])
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers something that's not a schema below a schema" do
      uri = 'http://jsi/schema_registry/3ij1'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri, 'properties' => {}})
      err = assert_raises(ArgumentError) do
        schema_registry.register(resource.properties)
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers the same schema twice" do
      uri = 'http://jsi/schema_registry/r3fh'
      schema_registry.register(JSI::JSONSchemaDraft07.new_schema({'$id' => uri}))
      schema_registry.register(JSI::JSONSchemaDraft07.new_schema({'$id' => uri}))
      assert_equal(JSI::JSONSchemaDraft07.new_schema({'$id' => uri}), schema_registry.find(uri))
    end

    it "registers two different things with the same URI" do
      uri = 'http://jsi/schema_registry/y7xu'
      # use new_jsi instead of new_schema to skip auto registration
      res1 = JSI::JSONSchemaDraft07.new_jsi({'$id' => uri, 'title' => 'res1'})
      res2 = JSI::JSONSchemaDraft07.new_jsi({'$id' => uri, 'title' => 'res2'})
      schema_registry.register(res1)
      err = assert_raises(JSI::SchemaRegistry::Collision) do
        schema_registry.register(res2)
      end
      msg = <<~MSG
        URI collision on http://jsi/schema_registry/y7xu.
        existing:
        \#{<JSI (JSI::JSONSchemaDraft07) Schema>
          "$id" => "http://jsi/schema_registry/y7xu",
          "title" => "res1"
        }
        new:
        \#{<JSI (JSI::JSONSchemaDraft07) Schema>
          "$id" => "http://jsi/schema_registry/y7xu",
          "title" => "res2"
        }
        MSG
      assert_equal(msg.chomp, err.message)
      assert_equal(res1, schema_registry.find(uri))
    end

    it 'autoloads a schema uri and finds it' do
      uri = 'http://jsi/schema_registry/hnsm'
      schema_registry.autoload_uri(uri) do
        JSI.new_schema({
          '$schema' => 'http://json-schema.org/draft-07/schema',
          '$id' => uri,
        })
      end
      assert_uri(uri, schema_registry.find(uri).schema_absolute_uri)
    end

    it 'autoloads a schema uri containing that resource but not at document root' do
      uri = 'http://jsi/schema_registry/6uav'
      schema_registry.autoload_uri(uri) do
        JSI.new_schema({
          '$schema' => 'http://json-schema.org/draft-07/schema',
          'items' => {
            'definitions' => {
              's' => {
                '$id' => uri,
              }
            }
          }
        })
      end
      resource = schema_registry.find(uri)
      assert_uri(uri, resource.schema_absolute_uri)
      assert_equal(JSI::Ptr['items', 'definitions', 's'], resource.jsi_ptr)
    end

    it 'autoloads a schema uri containing that resource but not at document root' do
      uri = 'http://jsi/schema_registry/5mgm'
      schema_registry.autoload_uri(uri) do
        schema = JSI.new_schema({
          '$schema' => 'http://json-schema.org/draft-07/schema',
          'additionalProperties' => {
            '$ref' => 'http://json-schema.org/draft-07/schema',
          }
        })
        schema.new_jsi({'x' => {'$id' => uri}})
      end
      resource = schema_registry.find(uri)
      assert_uri(uri, resource.schema_absolute_uri)
      assert_equal(JSI::Ptr['x'], resource.jsi_ptr)
    end

    it 'autoloads a nonschema uri and finds it' do
      uri = 'http://jsi/schema_registry/0vsi'
      schema_registry.autoload_uri(uri) do
        JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}, uri: uri)
      end
      assert_uri(uri, schema_registry.find(uri).jsi_resource_ancestor_uri)
    end

    it 'autoloads a uri but the resource is not in the JSI from the block' do
      uri = 'http://jsi/schema_registry/6d86'
      schema_registry.autoload_uri(uri) do
        JSI::JSONSchemaDraft07.new_schema({}).new_jsi({})
      end
      err = assert_raises(JSI::SchemaRegistry::ResourceNotFound) do
        schema_registry.find(uri)
      end
      msg = <<~MSG
        URI http://jsi/schema_registry/6d86 was registered with autoload_uri but the result did not contain a resource with that URI.
        the resource resulting from autoload_uri was:
        \#{<JSI>}
        MSG
      assert_equal(msg.chomp, err.message)
    end

    it 'autoloads a uri but the block does not result in a JSI' do
      uri = 'http://jsi/schema_registry/hmaa'
      schema_registry.autoload_uri(uri) do
        {}
      end
      err = assert_raises(ArgumentError) do
        schema_registry.find(uri)
      end
      assert_equal("resource must be a JSI::Base. got: {}", err.message)
    end

    it 'tries to autoload / find a URI that is relative' do
      uri = '/schema_registry/4ppr'
      err = assert_raises(JSI::SchemaRegistry::NonAbsoluteURI) { schema_registry.autoload_uri(uri) }
      assert_equal("JSI::SchemaRegistry only registers absolute URIs. cannot access relative URI: /schema_registry/4ppr", err.message)
      err = assert_raises(JSI::SchemaRegistry::NonAbsoluteURI) { schema_registry.find(uri) }
      assert_equal("JSI::SchemaRegistry only registers absolute URIs. cannot access relative URI: /schema_registry/4ppr", err.message)
    end

    it 'tries to autoload / find a URI with a fragment' do
      uri = 'http://jsi/schema_registry/8wtm#foo'
      err = assert_raises(JSI::SchemaRegistry::NonAbsoluteURI) { schema_registry.autoload_uri(uri) }
      assert_equal("JSI::SchemaRegistry only registers absolute URIs. cannot access URI with fragment: http://jsi/schema_registry/8wtm#foo", err.message)
      err = assert_raises(JSI::SchemaRegistry::NonAbsoluteURI) { schema_registry.find(uri) }
      assert_equal("JSI::SchemaRegistry only registers absolute URIs. cannot access URI with fragment: http://jsi/schema_registry/8wtm#foo", err.message)
    end

    it "registers a URI with two different autoloads" do
      uri = 'http://jsi/schema_registry/rz4l'
      schema_registry.autoload_uri(uri) { x }
      err = assert_raises(JSI::SchemaRegistry::Collision) { schema_registry.autoload_uri(uri) { y } }
      msg = <<~MSG
        already registered URI for autoload
        URI: http://jsi/schema_registry/rz4l
        loader: #<Proc:
        MSG
      assert(err.message.start_with?(msg.chomp))
    end

    it "registers autoload without a block" do
      uri = 'http://jsi/schema_registry/j0s5'
      err = assert_raises(ArgumentError) { schema_registry.autoload_uri(uri) }
      msg = <<~MSG
        JSI::SchemaRegistry#autoload_uri must be invoked with a block
        URI: http://jsi/schema_registry/j0s5
        MSG
      assert_equal(msg.chomp, err.message)
    end

    it 'dups' do
      register_uri = 'http://jsi/schema_registry/p4z7'
      register_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri})
      schema_registry.register(register_resource)
      autoload_uri = 'http://jsi/schema_registry/adf8'
      schema_registry.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      schema_registry_dup = schema_registry.dup
      assert_uri(register_uri, schema_registry_dup.find(register_uri).schema_absolute_uri)
      assert_equal(register_resource, schema_registry_dup.find(register_uri))
      assert_uri(autoload_uri, schema_registry_dup.find(autoload_uri).schema_absolute_uri)

      # registering with the dup does not register in the original
      postdup_register_uri = 'http://jsi/schema_registry/ipzf'
      postdup_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => postdup_register_uri})
      schema_registry_dup.register(postdup_resource)
      assert_equal(postdup_resource, schema_registry_dup.find(postdup_register_uri))
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { schema_registry.find(postdup_register_uri) }

      postdup_autoload_uri = 'http://jsi/schema_registry/91wo'
      schema_registry_dup.autoload_uri(postdup_autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => postdup_autoload_uri})
      end
      assert_equal(postdup_autoload_uri, schema_registry_dup.find(postdup_autoload_uri)['$id'])
      assert_raises(JSI::SchemaRegistry::ResourceNotFound) { schema_registry.find(postdup_autoload_uri) }
    end

    it 'freezes' do
      register_uri = 'http://jsi/schema_registry/gj6v'
      register_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri})
      schema_registry.register(register_resource)
      autoload_uri = 'http://jsi/schema_registry/aszv'
      schema_registry.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      frozen = schema_registry.freeze
      assert(frozen.equal?(schema_registry))
      assert_equal(register_resource, schema_registry.find(register_uri))
      assert_raises(JSI::FrozenError) do
        schema_registry.find(autoload_uri)
      end
      s = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => 'http://jsi/schema_registry/5h5c'})
      assert_raises(JSI::FrozenError) do
        schema_registry.register(s)
      end
    end

    it 'freezes; #dup is unfrozen' do
      schema_registry.freeze
      dup = schema_registry.dup

      register_uri = 'http://jsi/schema_registry/79oh'
      dup.register(JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri}))
      assert_equal(register_uri, dup.find(register_uri)['$id'])

      autoload_uri = 'http://jsi/schema_registry/6j17'
      dup.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      assert_equal(autoload_uri, dup.find(autoload_uri)['$id'])
    end
  end
end
