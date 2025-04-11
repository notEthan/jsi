require_relative 'test_helper'

describe("JSI::Registry") do
  let(:registry) { JSI::DEFAULT_REGISTRY.dup }

  describe 'operation' do
    it 'registers a schema and finds it' do
      uri = 'http://jsi/registry/iepm'
      resource = JSI.new_schema({
        '$schema' => 'http://json-schema.org/draft-07/schema',
        '$id' => uri,
      })
      registry.register(resource)
      assert_equal(resource, registry.find(uri))
    end

    it 'does not find a schema that is not registered' do
      uri = 'http://jsi/registry/55e6'
      e = assert_raises(JSI::ResolutionError) { registry.find(uri) }
      assert_uri(uri, e.uri)
    end

    it 'registers a nonschema and finds it' do
      uri = 'http://jsi/registry/d7eu'
      resource = JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}, uri: uri)
      registry.register(resource)
      assert_equal(resource, registry.find(uri))
    end

    it 'registers a nonschema with no resource URIs' do
      resource = JSI::JSONSchemaDraft07.new_schema({}).new_jsi({})
      registry.register(resource)
    end

    it "registers something that's not a schema below document root with a URI" do
      uri = 'http://jsi/registry/skw7'
      resource = JSI::JSONSchemaDraft07.new_schema({'items' => {}}).new_jsi([{}], uri: uri)
      err = assert_raises(ArgumentError) do
        registry.register(resource[0])
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers something that's not a schema below document root without a URI" do
      resource = JSI::JSONSchemaDraft07.new_schema({'items' => {}}).new_jsi([{}])
      err = assert_raises(ArgumentError) do
        registry.register(resource[0])
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers something that's not a schema below a schema" do
      uri = 'http://jsi/registry/3ij1'
      resource = JSI::JSONSchemaDraft07.new_schema({'$id' => uri, 'properties' => {}})
      err = assert_raises(ArgumentError) do
        registry.register(resource.properties)
      end
      assert_equal("undefined behavior: registration of a JSI which is not a schema and is not at the root of a document", err.message)
    end

    it "registers the same schema twice" do
      uri = 'http://jsi/registry/r3fh'
      schema = JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, register: false)
      registry.register(schema)
      registry.register(schema)
    end

    it("registers two equal schemas") do
      uri = 'http://jsi/registry/r3fi'
      schema = JSI::JSONSchemaDraft07.new_schema({'$id' => uri}, register: false)
      registry.register(schema)
      assert_raises(JSI::Registry::Collision) do
        registry.register(JSI::JSONSchemaDraft07.new_schema({'$id' => uri}))
      end
    end

    it "registers two different things with the same URI" do
      uri = 'http://jsi/registry/y7xu'
      # use new_jsi instead of new_schema to skip auto registration
      res1 = JSI::JSONSchemaDraft07.new_jsi({'$id' => uri, 'title' => 'res1'})
      res2 = JSI::JSONSchemaDraft07.new_jsi({'$id' => uri, 'title' => 'res2'})
      registry.register(res1)
      err = assert_raises(JSI::Registry::Collision) do
        registry.register(res2)
      end
      msg = <<~MSG
        URI collision on http://jsi/registry/y7xu.
        existing:
        \#{<JSI (JSI::JSONSchemaDraft07) Schema>
          "$id" => "http://jsi/registry/y7xu",
          "title" => "res1"
        }
        new:
        \#{<JSI (JSI::JSONSchemaDraft07) Schema>
          "$id" => "http://jsi/registry/y7xu",
          "title" => "res2"
        }
        MSG
      assert_equal(msg.chomp, err.message)
      assert_equal(res1, registry.find(uri))
    end

    it 'autoloads a schema uri and finds it' do
      uri = 'http://jsi/registry/hnsm'
      registry.autoload_uri(uri) do
        JSI.new_schema({
          '$schema' => 'http://json-schema.org/draft-07/schema',
          '$id' => uri,
        })
      end
      assert_uri(uri, registry.find(uri).schema_absolute_uri)
    end

    it 'autoloads a schema uri containing that resource but not at document root' do
      uri = 'http://jsi/registry/6uav'
      registry.autoload_uri(uri) do
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
      resource = registry.find(uri)
      assert_uri(uri, resource.schema_absolute_uri)
      assert_equal(JSI::Ptr['items', 'definitions', 's'], resource.jsi_ptr)
    end

    it 'autoloads a schema uri containing that resource but not at document root' do
      uri = 'http://jsi/registry/5mgm'
      registry.autoload_uri(uri) do
        schema = JSI.new_schema({
          '$schema' => 'http://json-schema.org/draft-07/schema',
          'additionalProperties' => {
            '$ref' => 'http://json-schema.org/draft-07/schema',
          }
        })
        schema.new_jsi({'x' => {'$id' => uri}})
      end
      resource = registry.find(uri)
      assert_uri(uri, resource.schema_absolute_uri)
      assert_equal(JSI::Ptr['x'], resource.jsi_ptr)
    end

    it 'autoloads a nonschema uri and finds it' do
      uri = 'http://jsi/registry/0vsi'
      registry.autoload_uri(uri) do
        JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}, uri: uri)
      end
      assert_uri(uri, registry.find(uri).jsi_resource_ancestor_uri)
    end

    it 'autoloads a uri but the resource is not in the JSI from the block' do
      uri = 'http://jsi/registry/6d86'
      registry.autoload_uri(uri) do
        JSI::JSONSchemaDraft07.new_schema({}).new_jsi({})
      end
      err = assert_raises(JSI::ResolutionError) do
        registry.find(uri)
      end
      msg = <<~MSG
        URI http://jsi/registry/6d86 was registered for autoload but the result did not contain an entity with that URI.
        autoload result was:
        \#{<JSI*1>}
        MSG
      assert_equal(msg.chomp, err.message)
    end

    it 'autoloads a uri but the block does not result in a JSI' do
      uri = 'http://jsi/registry/hmaa'
      registry.autoload_uri(uri) do
        {}
      end
      err = assert_raises(ArgumentError) do
        registry.find(uri)
      end
      assert_equal("resource must be a JSI::Base. got: {}", err.message)
    end

    it 'tries to autoload / find a URI that is relative' do
      uri = '/registry/4ppr'
      err = assert_raises(JSI::URIError) { registry.autoload_uri(uri) }
      assert_equal(%q(URI must be an absolute URI. got: "/registry/4ppr"), err.message)
      err = assert_raises(JSI::URIError) { registry.find(uri) }
      assert_equal(%q(URI must be an absolute URI. got: "/registry/4ppr"), err.message)
    end

    it 'tries to autoload / find a URI with a fragment' do
      uri = 'http://jsi/registry/8wtm#foo'
      err = assert_raises(JSI::URIError) { registry.autoload_uri(uri) }
      assert_equal(%q(URI must have no fragment. got: "http://jsi/registry/8wtm#foo"), err.message)
      err = assert_raises(JSI::URIError) { registry.find(uri) }
      assert_equal(%q(URI must have no fragment. got: "http://jsi/registry/8wtm#foo"), err.message)
    end

    it "registers a URI with two different autoloads" do
      uri = 'http://jsi/registry/rz4l'
      registry.autoload_uri(uri) { x }
      err = assert_raises(JSI::Registry::Collision) { registry.autoload_uri(uri) { y } }
      msg = <<~MSG
        already registered URI for autoload
        URI: http://jsi/registry/rz4l
        loader: #<Proc:
        MSG
      assert(err.message.start_with?(msg.chomp))
    end

    it "registers autoload without a block" do
      uri = 'http://jsi/registry/j0s5'
      err = assert_raises(ArgumentError) { registry.autoload_uri(uri) }
      msg = <<~MSG
        JSI::Registry autoload must be invoked with a block
        URI: http://jsi/registry/j0s5
        MSG
      assert_equal(msg.chomp, err.message)
    end
  end

  describe("pretty") do
    let(:registry) do
      JSI::Registry.new.tap do |registry|
        registry.register(JSI::JSONSchemaDraft04.schema)
        registry.autoload_uri("http://json-schema.org/draft-06/schema") { } # never mind the block, not actually loading
        registry.autoload_uri("http://json-schema.org/draft-07/schema") { }
        registry.autoload_dialect_uri("http://json-schema.org/draft-04/schema") { }
      end
    end

    it('#pretty_print') do
      pp = <<~PP
      #<JSI::Registry
        resources (1): <"http://json-schema.org/draft-04/schema">
        resources autoload (2): <
          "http://json-schema.org/draft-06/schema",
          "http://json-schema.org/draft-07/schema"
        >
        vocabularies (0)
        vocabularies autoload (0)
        dialects (0)
        dialects autoload (1): <"http://json-schema.org/draft-04/schema">
      >
      PP
      assert_equal(pp, registry.pretty_inspect)
    end

    it('#inspect') do
      assert_equal(%q(#<JSI::Registry resources (1): <"http://json-schema.org/draft-04/schema"> resources autoload (2): <"http://json-schema.org/draft-06/schema", "http://json-schema.org/draft-07/schema"> vocabularies (0) vocabularies autoload (0) dialects (0) dialects autoload (1): <"http://json-schema.org/draft-04/schema">>), registry.inspect)
    end
  end

  describe("dup and freeze") do
    it 'dups' do
      register_uri = 'http://jsi/registry/p4z7'
      register_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri})
      registry.register(register_resource)
      autoload_uri = 'http://jsi/registry/adf8'
      registry.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      registry_dup = registry.dup
      assert_uri(register_uri, registry_dup.find(register_uri).schema_absolute_uri)
      assert_equal(register_resource, registry_dup.find(register_uri))
      assert_uri(autoload_uri, registry_dup.find(autoload_uri).schema_absolute_uri)

      # registering with the dup does not register in the original
      postdup_register_uri = 'http://jsi/registry/ipzf'
      postdup_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => postdup_register_uri})
      registry_dup.register(postdup_resource)
      assert_equal(postdup_resource, registry_dup.find(postdup_register_uri))
      assert_raises(JSI::ResolutionError) { registry.find(postdup_register_uri) }

      postdup_autoload_uri = 'http://jsi/registry/91wo'
      registry_dup.autoload_uri(postdup_autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => postdup_autoload_uri})
      end
      assert_equal(postdup_autoload_uri, registry_dup.find(postdup_autoload_uri)['$id'])
      assert_raises(JSI::ResolutionError) { registry.find(postdup_autoload_uri) }
    end

    it 'freezes' do
      register_uri = 'http://jsi/registry/gj6v'
      register_resource = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri})
      registry.register(register_resource)
      autoload_uri = 'http://jsi/registry/aszv'
      registry.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      frozen = registry.freeze
      assert(frozen.equal?(registry))
      assert_equal(register_resource, registry.find(register_uri))
      assert_raises(JSI::FrozenError) do
        registry.find(autoload_uri)
      end
      s = JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => 'http://jsi/registry/5h5c'})
      assert_raises(JSI::FrozenError) do
        registry.register(s)
      end
    end

    it 'freezes; #dup is unfrozen' do
      registry.freeze
      dup = registry.dup

      register_uri = 'http://jsi/registry/79oh'
      dup.register(JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => register_uri}))
      assert_equal(register_uri, dup.find(register_uri)['$id'])

      autoload_uri = 'http://jsi/registry/6j17'
      dup.autoload_uri(autoload_uri) do
        JSI.new_schema({'$schema' => 'http://json-schema.org/draft-07/schema', '$id' => autoload_uri})
      end
      assert_equal(autoload_uri, dup.find(autoload_uri)['$id'])
    end
  end
end

$test_report_file_loaded[__FILE__]
