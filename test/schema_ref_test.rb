require_relative 'test_helper'

describe JSI::Schema::Ref do
  let(:schema) do
    JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07)
  end

  describe 'pointers' do
    describe 'traces to nowhere' do
      describe 'resource root schema' do
        let(:schema_content) do
          {"$ref" => "#/no"}
        end

        it 'finds none' do
          err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
          msg = <<~MSG
            could not resolve pointer: "/no"
            from: \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "#/no"}
            in schema resource root: \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "#/no"}
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

          err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
          msg = <<~MSG
            could not resolve pointer: "/no"
            from: \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "#/no"}
            in schema resource root: #[<JSI> \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "#/no"}]
            MSG
          assert_equal(msg.chomp, err.message)
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
        err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
        msg = <<~MSG
          could not find schema by fragment: "no"
          in schema resource root: \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "#no"}
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
        }))
      end

      it 'finds a collision' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.definitions['ref'].new_jsi({}) }
        msg = <<~MSG
          found multiple schemas for plain name fragment "collide":
          \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$id" => "#collide"}
          \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$id" => "#collide"}
          MSG
        assert_equal(msg.chomp, err.message)
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
        err = assert_raises(JSI::SchemaRegistry::ResourceNotFound) { schema.new_jsi({}) }
        assert_match(%r(\AURI http://jsi/no is not registered. registered URIs:), err.message)
      end

      it 'errors from the registry (no ref_schema)' do
        err = assert_raises(JSI::SchemaRegistry::ResourceNotFound) { JSI::Schema::Ref.new(uri).deref_schema  }
        assert_match(%r(\AURI http://jsi/no is not registered. registered URIs:), err.message)
      end
    end

    describe 'relative uri' do
      let(:uri) { 'no#x' }
      let(:schema_content) do
        {'$ref' => uri}
      end

      it 'errors' do
        err = assert_raises(JSI::Schema::ReferenceError) { schema.new_jsi({}) }
        msg = <<~MSG
          cannot find schema by ref: no#x
          from: \#{<JSI (JSI::JSONSchemaOrgDraft07) Schema> "$ref" => "no#x"}
          MSG
        assert_equal(msg.chomp, err.message)
      end

      it 'errors (no ref_schema)' do
        err = assert_raises(JSI::Schema::ReferenceError) { JSI::Schema::Ref.new(uri).deref_schema  }
        assert_equal('cannot find schema by ref: no#x', err.message)
      end
    end

    describe 'pointer-only uri' do
      it 'errors (no ref_schema)' do
        err = assert_raises(JSI::Schema::ReferenceError) { JSI::Schema::Ref.new('#/no').deref_schema  }
        msg = <<~MSG
          cannot find schema by ref: #/no
          with no ref schema
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end

    describe 'anchor-only uri' do
      it 'errors (no ref_schema)' do
        err = assert_raises(JSI::Schema::ReferenceError) { JSI::Schema::Ref.new('#no').deref_schema  }
        msg = <<~MSG
          cannot find schema by ref: #no
          with no ref schema
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
        JSI.schema_registry.autoload_uri(uri) do
          JSI::JSONSchemaOrgDraft07.new_schema({}).new_jsi({}, uri: uri)
        end

        err = assert_raises(JSI::Schema::NotASchemaError) { schema.new_jsi({}) }
        msg = <<~MSG
          object identified by uri http://jsi/ref_to_not_a_schema is not a schema:
          \#{<JSI>}
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
      ref_with_schema = JSI::Schema::Ref.new(uri, schema)
      assert_equal('#<JSI::Schema::Ref http://jsi/3tzc>', ref_with_schema.inspect)
      assert_equal('#<JSI::Schema::Ref http://jsi/3tzc>', ref_with_schema.pretty_inspect.chomp)
      assert_equal(ref_with_schema.inspect, ref_with_schema.to_s)
      ref_no_schema = JSI::Schema::Ref.new(uri)
      assert_equal('#<JSI::Schema::Ref http://jsi/3tzc>', ref_no_schema.inspect)
      assert_equal('#<JSI::Schema::Ref http://jsi/3tzc>', ref_no_schema.pretty_inspect.chomp)
      assert_equal(ref_no_schema.inspect, ref_no_schema.to_s)
    end
  end
end
