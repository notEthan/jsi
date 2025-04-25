require_relative 'test_helper'

describe("JSI::Ref, JSI::Schema::Ref") do
  let(:schema) do
    JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07)
  end

  describe 'pointers' do
    describe 'traces to nowhere' do
      describe 'resource root schema' do
        let(:schema_content) do
          {"$ref" => "#/no"}
        end

        it 'finds none' do
          err = assert_raises(JSI::ResolutionError) { schema.new_jsi({}) }
          msg = <<~MSG
            could not resolve pointer: "/no"
            from: \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "#/no"}
            in resource root: \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "#/no"}
            MSG
          assert_equal(msg.chomp, err.message)
        end
      end

      describe 'resource root nonschema' do
        it 'finds none' do
          schemaschema = JSI.new_schema({
            '$schema' => "http://json-schema.org/draft-07/schema#",
            'items' => {'$ref' => "http://json-schema.org/draft-07/schema#"},
          })

          schema = schemaschema.new_jsi([{'$ref' => '#/no'}])[0]

          err = assert_raises(JSI::ResolutionError) { schema.new_jsi({}) }
          msg = <<~MSG
            could not resolve pointer: "/no"
            from: \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "#/no"}
            in resource root: #[<JSI*1> \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "#/no"}]
            MSG
          assert_equal(msg.chomp, err.message)
        end
      end

      describe("from a non-schema") do
        it("finds none") do
          referrer = JSI::SchemaSet[].new_jsi({'a' => {'b' => {}}})
          assert_raises(JSI::ResolutionError) { JSI::Ref.new('#/b', referrer: referrer).resolve }
          assert_raises(JSI::ResolutionError) { JSI::Ref.new('#/b', referrer: referrer['a']).resolve }
        end
      end
    end
  end

  describe 'anchors' do
    describe 'no anchor' do
      let(:schema_content) do
        {"$ref" => "#no"}
      end

      it 'finds none' do
        err = assert_raises(JSI::ResolutionError) { schema.new_jsi({}) }
        msg = <<~MSG
          could not resolve fragment: "no"
          in resource root: \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "#no"}
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end

    describe 'conflicting siblings' do
      let(:schema_content) do
        JSON.parse(%q({
          "definitions": {
            "sibling1": {"$id": "#collide"},
            "sibling2": {"$id": "#collide"},
            "ref": {"$ref": "#collide"}
          }
        }), freeze: true)
      end

      it 'finds a collision' do
        err = assert_raises(JSI::ResolutionError) { schema.definitions['ref'].new_jsi({}) }
        msg = <<~MSG
          found multiple schemas for plain name fragment "collide":
          \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$id" => "#collide"}
          \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$id" => "#collide"}
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end

    describe("referrer not a schema") do
      it("finds none") do
        referrer = JSI::SchemaSet[].new_jsi({'a' => {'b' => {}}})
        assert_raises(JSI::ResolutionError) { JSI::Ref.new('#a', referrer: referrer).resolve }
        assert_raises(JSI::ResolutionError) { JSI::Ref.new('#a', referrer: referrer['a']).resolve }
      end

      it("does not find a schema with that anchor") do
        referrer_schema = JSI::JSONSchemaDraft07.new_schema({"items" => {"$ref" => JSI::JSONSchemaDraft07.schema.id}})
        referrer = referrer_schema.new_jsi([{"$id" => "#a"}, {}])
        # from a non-schema
        assert_raises(JSI::ResolutionError) { JSI::Ref.new('#a', referrer: referrer).resolve }
        # from a schema
        assert_raises(JSI::ResolutionError) { JSI::Ref.new('#a', referrer: referrer[1]).resolve }
        # it does resolve as a schema ref though
        assert_equal(referrer[0], JSI::Schema::Ref.new('#a', referrer: referrer[1]).resolve)
      end
    end
  end

  describe 'unfindable resources' do
    describe 'absolute uri' do
      let(:uri) { 'http://jsi/no' }
      let(:schema_content) do
        {'$ref' => uri}
      end

      it 'errors from the registry' do
        err = assert_raises(JSI::ResolutionError) { schema.new_jsi({}) }
        assert_match(%r(\AURI http://jsi/no is not registered. registered URIs:), err.message)
      end

      it("errors from the registry (no referrer)") do
        err = assert_raises(JSI::ResolutionError) { JSI::Ref.new(uri).resolve }
        assert_match(%r(\AURI http://jsi/no is not registered. registered URIs:), err.message)
      end

      it("errors from the registry (no registry)") do
        schema_without_registry = JSI::JSONSchemaDraft07.new_schema(schema_content, registry: nil)
        err = assert_raises(JSI::ResolutionError) { JSI::Ref.new(uri, referrer: schema_without_registry).resolve }
        assert_match(%r(\Acould not resolve remote ref with no registry specified), err.message)
      end
    end

    describe 'relative uri' do
      let(:uri) { 'no#x' }
      let(:schema_content) do
        {'$ref' => uri}
      end

      it 'errors' do
        err = assert_raises(JSI::ResolutionError) { schema.new_jsi({}) }
        msg = <<~MSG
          cannot resolve ref: no#x
          from: \#{<JSI (JSI::JSONSchemaDraft07) Schema> "$ref" => "no#x"}
          MSG
        assert_equal(msg.chomp, err.message)
      end

      it("errors (no referrer)") do
        err = assert_raises(JSI::ResolutionError) { JSI::Ref.new(uri).resolve }
        assert_equal('cannot resolve ref: no#x', err.message)
      end

      it("resolves from non-schema") do
        x = JSI::SchemaSet[].new_jsi({'a' => {}}, uri: 'tag:gb2/x', registry: JSI::Registry.new, register: true)
        assert_equal(x, JSI::Ref.new('x', referrer: x['a']).resolve)
        assert_equal(x['a'], JSI::Ref.new('x#/a', referrer: x['a']).resolve)
        extreferrer = JSI::SchemaSet[].new_jsi({}, uri: 'tag:gb2/root', registry: x.jsi_registry)
        assert_equal(x, JSI::Ref.new('x', referrer: extreferrer).resolve)
        assert_equal(x['a'], JSI::Ref.new('x#/a', referrer: extreferrer).resolve)
      end
    end

    describe 'pointer-only uri' do
      it("errors (no referrer)") do
        err = assert_raises(JSI::ResolutionError) { JSI::Ref.new('#/no').resolve }
        msg = <<~MSG
          cannot resolve ref: #/no
          with no referrer
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end

    describe 'anchor-only uri' do
      it("errors (no referrer)") do
        err = assert_raises(JSI::ResolutionError) { JSI::Ref.new('#no').resolve }
        msg = <<~MSG
          cannot resolve ref: #no
          with no referrer
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end
  end

  describe 'not a schema' do
    describe 'remote ref in resource root nonschema' do
      let(:uri) { 'http://jsi/ref_to_not_a_schema' }
      let(:schema_content) do
        {'$ref' => uri}
      end

      it 'finds a thing that is not a schema' do
        JSI.registry.autoload_uri(uri) do
          JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}, uri: uri)
        end

        err = assert_raises(JSI::Schema::NotASchemaError) { schema.new_jsi({}) }
        msg = <<~MSG
          object identified by uri http://jsi/ref_to_not_a_schema is not a schema:
          \#{<JSI*1>}
          its schemas (which should include a Meta-Schema): JSI::SchemaSet[\#{<JSI (JSI::JSONSchemaDraft07) Schema>}]
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end
  end

  describe 'pretty' do
    let(:uri) { 'http://jsi/3tzc' }
    let(:schema_content) do
      {'$ref' => uri}
    end

    it 'is pretty' do
      ref_with_schema = JSI::Ref.new(uri, referrer: schema)
      assert_equal('#<JSI::Ref http://jsi/3tzc>', ref_with_schema.inspect)
      assert_equal('#<JSI::Ref http://jsi/3tzc>', ref_with_schema.pretty_inspect.chomp)
      assert_equal(ref_with_schema.inspect, ref_with_schema.to_s)
      ref_no_schema = JSI::Ref.new(uri)
      assert_equal('#<JSI::Ref http://jsi/3tzc>', ref_no_schema.inspect)
      assert_equal('#<JSI::Ref http://jsi/3tzc>', ref_no_schema.pretty_inspect.chomp)
      assert_equal(ref_no_schema.inspect, ref_no_schema.to_s)
    end
  end
end

$test_report_file_loaded[__FILE__]
