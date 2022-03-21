require_relative 'test_helper'

describe JSI::Schema do
  describe 'new_schema' do
    it 'initializes from a hash' do
      schema = JSI.new_schema({'type' => 'object'}, default_metaschema: JSI::JSONSchemaOrgDraft07)
      assert_equal({'type' => 'object'}, schema.jsi_instance)
    end

    it 'cannot instantiate from a non-string $schema' do
      err = assert_raises(ArgumentError) { JSI.new_schema({'$schema' => Object.new}) }
      assert_equal("given schema_object keyword `$schema` is not a string", err.message)
    end

    it 'cannot instantiate from some unknown object' do
      err = assert_raises(TypeError) { JSI.new_schema(Object.new, default_metaschema: JSI::JSONSchemaOrgDraft07) }
      assert_match(/\Acannot instantiate Schema from: #<Object:.*>\z/m, err.message)
    end
    it 'instantiating a schema from a schema returns that schema' do
      assert_equal(
        JSI.new_schema({}, default_metaschema: JSI::JSONSchemaOrgDraft07),
        JSI.new_schema(JSI.new_schema({}, default_metaschema: JSI::JSONSchemaOrgDraft07), default_metaschema: JSI::JSONSchemaOrgDraft07)
      )
    end
  end
  describe 'as an instance of metaschema' do
    let(:metaschema_jsi_module) { JSI::JSONSchemaOrgDraft04 }
    let(:schema_content) { {'type' => 'array', 'items' => {'description' => 'items!'}} }
    let(:schema) { metaschema_jsi_module.new_jsi(schema_content) }
    it '#[]' do
      schema_items = schema['items']
      assert_is_a(metaschema_jsi_module, schema_items)
      assert_equal({'description' => 'items!'}, schema_items.jsi_instance)
    end
  end
  describe '#schema_uri' do
    it "hasn't got one" do
      assert_nil(JSI::JSONSchemaOrgDraft07.new_schema({}).schema_uri)
    end
    it 'uses a given id ignoring an empty fragment' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/given_id_with_fragment#'})
      assert_equal('http://jsi/schema/given_id_with_fragment', schema.schema_uri.to_s)
    end
    it 'uses a given id with no fragment' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/given_id'})
      assert_equal('http://jsi/schema/given_id', schema.schema_uri.to_s)
    end
    it 'uses a pointer in the fragment' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({
        '$id' => 'http://jsi/schema/uses_pointer_in_fragment#',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('http://jsi/schema/uses_pointer_in_fragment#/properties/foo', subschema.schema_uri.to_s)
    end
    it 'uses a pointer in the fragment, ignoring a pointer in the fragment of the root id' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({
        '$id' => 'http://jsi/schema/id_has_pointer#/notroot',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('http://jsi/schema/id_has_pointer#/properties/foo', subschema.schema_uri.to_s)
    end
  end
  describe '#schema_uris' do
    let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
    describe 'two ids' do
      let(:schema_content) do
        {
          "$id": "https://example.com/foo",
          "items": {
            "$id": "https://example.com/bar",
            "additionalProperties": { }
          }
        }
      end
      it 'has its absolute URI and both by pointer fragment' do
        assert_equal([
          "https://example.com/bar",
          "https://example.com/bar#",
          "https://example.com/foo#/items",
        ], schema.items.schema_uris.map(&:to_s))
      end
    end
    describe 'conflicting anchors' do
      let(:schema) do
        JSI::JSONSchemaOrgDraft06.new_schema(JSON.parse(%q({
          "$id": "http://jsi/schema_uris/q0wo",
          "definitions": {
            "sibling1": {"$id": "#collide"},
            "sibling2": {"$id": "#collide"},
            "child": {
              "$id": "#X",
              "definitions": {
                "rel": {
                  "$id": "z268",
                  "definitions": {
                    "x": {"$id": "#X"}
                  }
                }
              }
            }
          }
        })))
      end

      it 'has the specified uris' do
        all_exp_uris = {
          "#" => [
            "http://jsi/schema_uris/q0wo",
            "http://jsi/schema_uris/q0wo#",
          ],
          "#/definitions/sibling1" => [
            "http://jsi/schema_uris/q0wo#/definitions/sibling1",
            # no #collide
          ],
          "#/definitions/sibling2" => [
            "http://jsi/schema_uris/q0wo#/definitions/sibling2",
            # no #collide
          ],
          "#/definitions/child" => [
            # #X collides with anchor in different child resource
            "http://jsi/schema_uris/q0wo#/definitions/child",
          ],
          "#/definitions/child/definitions/rel" => [
            "http://jsi/schema_uris/z268",
            "http://jsi/schema_uris/z268#",
            "http://jsi/schema_uris/q0wo#/definitions/child/definitions/rel",
          ],
          "#/definitions/child/definitions/rel/definitions/x" => [
            "http://jsi/schema_uris/z268#X",
            "http://jsi/schema_uris/z268#/definitions/x",
            # no "http://jsi/schema_uris/q0wo#X"; we detect that the anchor no longer
            # refers to self in the parent resource (it becomes ambiguous)
            "http://jsi/schema_uris/q0wo#/definitions/child/definitions/rel/definitions/x",
          ],
        }
        all_act_uris = all_exp_uris.keys.map do |uri|
          subschema = JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(schema)
          {uri => subschema.schema_uris.map(&:to_s)}
        end.inject({}, &:update)
        assert_equal(all_exp_uris, all_act_uris)
      end
    end

    describe 'draft4 example' do
      let(:schema) do
        # adapted from https://datatracker.ietf.org/doc/html/draft-zyp-json-schema-04#section-7.2.2
        # but changed so only schemas use ids
        JSI::JSONSchemaOrgDraft04.new_schema(JSON.parse(%q({
          "id": "http://x.y.z/rootschema.json#",
          "definitions": {
            "schema1": {
              "id": "#foo"
            },
            "schema2": {
              "id": "otherschema.json",
              "definitions": {
                "nested": {
                  "id": "#bar"
                },
                "alsonested": {
                  "id": "t/inner.json#a"
                }
              }
            },
            "schema3": {
              "id": "some://where.else/completely#"
            }
          }
        })))
      end

      it 'has the specified uris' do
        all_exp_uris = {
          '#' => [
            "http://x.y.z/rootschema.json",
            "http://x.y.z/rootschema.json#",
          ],
          '#/definitions/schema1' => [
            "http://x.y.z/rootschema.json#foo",
            "http://x.y.z/rootschema.json#/definitions/schema1",
          ],
          '#/definitions/schema2' => [
            'http://x.y.z/otherschema.json',
            'http://x.y.z/otherschema.json#',
            'http://x.y.z/rootschema.json#/definitions/schema2',
          ],
          '#/definitions/schema2/definitions/nested' => [
            "http://x.y.z/otherschema.json#bar",
            "http://x.y.z/otherschema.json#/definitions/nested",
            "http://x.y.z/rootschema.json#bar",
            "http://x.y.z/rootschema.json#/definitions/schema2/definitions/nested",
          ],
          '#/definitions/schema2/definitions/alsonested' => [
            "http://x.y.z/t/inner.json",
            "http://x.y.z/t/inner.json#a",
            "http://x.y.z/t/inner.json#",
            "http://x.y.z/otherschema.json#a",
            "http://x.y.z/otherschema.json#/definitions/alsonested",
            "http://x.y.z/rootschema.json#a",
            "http://x.y.z/rootschema.json#/definitions/schema2/definitions/alsonested",
          ],
          '#/definitions/schema3' => [
            "some://where.else/completely",
            "some://where.else/completely#",
            "http://x.y.z/rootschema.json#/definitions/schema3",
          ],
        }
        all_act_uris = all_exp_uris.keys.map do |uri|
          subschema = JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(schema)
          {uri => subschema.schema_uris.map(&:to_s)}
        end.inject({}, &:update)
        assert_equal(all_exp_uris, all_act_uris)
      end
    end

    describe 'draft6 example' do
      let(:schema) do
        # from https://datatracker.ietf.org/doc/html/draft-wright-json-schema-01#section-9.2
        JSI::JSONSchemaOrgDraft06.new_schema(JSON.parse(%q({
          "$id": "http://example.com/root.json",
          "definitions": {
            "A": { "$id": "#foo" },
            "B": {
              "$id": "other.json",
              "definitions": {
                "X": { "$id": "#bar" },
                "Y": { "$id": "t/inner.json" }
              }
            },
            "C": {
              "$id": "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f"
            }
          }
        })))
      end

      it 'has the specified uris' do
        all_exp_uris = {
          '#' => [
            "http://example.com/root.json",
            "http://example.com/root.json#",
          ],
          '#/definitions/A' => [
            "http://example.com/root.json#foo",
            "http://example.com/root.json#/definitions/A",
          ],
          '#/definitions/B' => [
            'http://example.com/other.json',
            'http://example.com/other.json#',
            'http://example.com/root.json#/definitions/B',
          ],
          '#/definitions/B/definitions/X' => [
            "http://example.com/other.json#bar",
            "http://example.com/other.json#/definitions/X",
            "http://example.com/root.json#bar",
            "http://example.com/root.json#/definitions/B/definitions/X",
          ],
          '#/definitions/B/definitions/Y' => [
            "http://example.com/t/inner.json",
            "http://example.com/t/inner.json#",
            "http://example.com/other.json#/definitions/Y",
            "http://example.com/root.json#/definitions/B/definitions/Y",
          ],
          '#/definitions/C' => [
            "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f",
            "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f#",
            "http://example.com/root.json#/definitions/C",
          ],
        }
        all_act_uris = all_exp_uris.keys.map do |uri|
          subschema = JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(schema)
          {uri => subschema.schema_uris.map(&:to_s)}
        end.inject({}, &:update)
        assert_equal(all_exp_uris, all_act_uris)
      end
    end
  end
  describe '#schema_absolute_uri, #anchor' do
    describe 'draft 4' do
      let(:metaschema) { JSI::JSONSchemaOrgDraft04 }
      it "hasn't got one" do
        schema = metaschema.new_schema({})
        assert_nil(schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id with an empty fragment' do
        schema = metaschema.new_schema({'id' => 'http://jsi/test/schema_absolute_uri/d4/empty_fragment#'})
        assert_equal('http://jsi/test/schema_absolute_uri/d4/empty_fragment', schema.schema_absolute_uri.to_s)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'id' => 'http://jsi/test/schema_absolute_uri/d4/given_id'})
        assert_equal('http://jsi/test/schema_absolute_uri/d4/given_id', schema.schema_absolute_uri.to_s)
        assert_nil(schema.anchor)
      end
      it 'nested schema without id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_no_id',
          'items' => {},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with absolute id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_abs_id_base',
          'items' => {'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_abs_id'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d4/nested_w_abs_id', schema.items.schema_absolute_uri.to_s)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id_base',
          'items' => {'id' => 'nested_w_rel_id'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id', schema.items.schema_absolute_uri.to_s)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with anchor id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_anchor_id_base',
          'items' => {'id' => '#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with anchor id on the base' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_anchor_on_base',
          'items' => {'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_anchor_on_base#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with anchor id on the base after resolution' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_anchor_on_base_rel',
          'items' => {'id' => 'nested_w_anchor_on_base_rel#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with id and fragment' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_id_frag_base',
          'items' => {'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_id_frag#nested_anchor'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d4/nested_w_id_frag', schema.items.schema_absolute_uri.to_s)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with id with empty fragment' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_id_empty_frag_base',
          'items' => {'id' => '#'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with empty id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_empty_id_base',
          'items' => {'id' => ''},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      describe 'externally supplied uri' do
        it 'schema with relative ids' do
          schema = metaschema.new_schema({
            'id' => 'root_relative',
            'properties' => {
              'relative' => {'id' => 'nested_relative'},
              'absolute' => {'id' => 'http://jsi/test/d4/ignore_external_uri/nested_absolute'},
              'none' => {},
            },
          }, uri: 'http://jsi/test/d4/external_uri/1')
          assert_equal('http://jsi/test/d4/external_uri/root_relative', schema.schema_absolute_uri.to_s)
          assert_equal('http://jsi/test/d4/external_uri/nested_relative', schema.properties['relative'].schema_absolute_uri.to_s)
          assert_equal('http://jsi/test/d4/ignore_external_uri/nested_absolute', schema.properties['absolute'].schema_absolute_uri.to_s)
          assert_nil(schema.properties['none'].schema_absolute_uri)
        end
      end
      describe 'relative id uri with no base' do
        it 'has no schema_absolute_uri' do
          schema = metaschema.new_schema({
            'id' => 'test/d4/relative_uri',
          })
          assert_nil(schema.schema_absolute_uri)
          assert_nil(schema.anchor)
        end
        it 'has no schema_absolute_uri but has an anchor' do
          schema = metaschema.new_schema({
            'id' => 'test/d4/relative_uri_w_anchor#anchor',
          })
          assert_nil(schema.schema_absolute_uri)
          assert_equal('anchor', schema.anchor)
        end
      end
    end
    describe 'draft 6' do
      let(:metaschema) { JSI::JSONSchemaOrgDraft06 }
      it "hasn't got one" do
        schema = metaschema.new_schema({})
        assert_nil(schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id with an empty fragment' do
        schema = metaschema.new_schema({'$id' => 'http://jsi/test/schema_absolute_uri/d6/empty_fragment#'})
        assert_equal('http://jsi/test/schema_absolute_uri/d6/empty_fragment', schema.schema_absolute_uri.to_s)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'$id' => 'http://jsi/test/schema_absolute_uri/d6/given_id'})
        assert_equal('http://jsi/test/schema_absolute_uri/d6/given_id', schema.schema_absolute_uri.to_s)
        assert_nil(schema.anchor)
      end
      it 'nested schema without id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_no_id',
          'items' => {},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with absolute id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_abs_id_base',
          'items' => {'$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_abs_id'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d6/nested_w_abs_id', schema.items.schema_absolute_uri.to_s)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id_base',
          'items' => {'$id' => 'nested_w_rel_id'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id', schema.items.schema_absolute_uri.to_s)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with anchor id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_anchor_id_base',
          'items' => {'$id' => '#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with anchor id on the base' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_anchor_on_base',
          'items' => {'$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_anchor_on_base#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with anchor id on the base after resolution' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_anchor_on_base_rel',
          'items' => {'$id' => 'nested_w_anchor_on_base_rel#nested_anchor'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with id and fragment' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_id_frag_base',
          'items' => {'$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_id_frag#nested_anchor'},
        })
        assert_equal('http://jsi/test/schema_absolute_uri/d6/nested_w_id_frag', schema.items.schema_absolute_uri.to_s)
        assert_equal('nested_anchor', schema.items.anchor)
      end
      it 'nested schema with id with empty fragment' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_id_empty_frag_base',
          'items' => {'$id' => '#'},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with empty id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_empty_id_base',
          'items' => {'$id' => ''},
        })
        assert_nil(schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      describe 'externally supplied uri' do
        it 'schema with relative ids' do
          schema = metaschema.new_schema({
            '$id' => 'root_relative',
            'properties' => {
              'relative' => {'$id' => 'nested_relative'},
              'absolute' => {'$id' => 'http://jsi/test/d6/ignore_external_uri/nested_absolute'},
              'none' => {},
            },
          }, uri: 'http://jsi/test/d6/external_uri/0')
          assert_equal('http://jsi/test/d6/external_uri/root_relative', schema.schema_absolute_uri.to_s)
          assert_equal('http://jsi/test/d6/external_uri/nested_relative', schema.properties['relative'].schema_absolute_uri.to_s)
          assert_equal('http://jsi/test/d6/ignore_external_uri/nested_absolute', schema.properties['absolute'].schema_absolute_uri.to_s)
          assert_nil(schema.properties['none'].schema_absolute_uri)
        end
      end
      describe 'relative id uri with no base' do
        it 'has no schema_absolute_uri' do
          schema = metaschema.new_schema({
            '$id' => 'test/d6/relative_uri',
          })
          assert_nil(schema.schema_absolute_uri)
          assert_nil(schema.anchor)
        end
        it 'has no schema_absolute_uri but has an anchor' do
          schema = metaschema.new_schema({
            '$id' => 'test/d6/relative_uri_w_anchor#anchor',
          })
          assert_nil(schema.schema_absolute_uri)
          assert_equal('anchor', schema.anchor)
        end
      end
    end
    describe 'externally supplied uri with JSI.new_schema' do
      it 'resolves' do
        schema = JSI.new_schema(
          {'$schema' => 'http://json-schema.org/draft-07/schema#', '$id' => 'tehschema'},
          uri: 'http://jsi/test/schema_absolute_uri/schema.new_base/0',
        )
        assert_equal('http://jsi/test/schema_absolute_uri/schema.new_base/tehschema', schema.schema_absolute_uri.to_s)
      end
    end
  end
  describe '#jsi_schema_module' do
    it 'returns the module for the schema' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/jsi_schema_module'})
      assert_is_a(JSI::SchemaModule, schema.jsi_schema_module)
      assert_equal(schema, schema.jsi_schema_module.schema)
    end

    it 'returns the same module for equal schemas' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/jsi_schema_module_eq'})
      schema_again = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/jsi_schema_module_eq'})
      assert_equal(schema.jsi_schema_module, schema_again.jsi_schema_module)
    end
  end

  describe '#jsi_schema_module_exec' do
    it 'evaluates the block on the schema module' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'id' => 'https://schemas.jsi.unth.net/test/jsi_schema_module_exec'})
      schema.jsi_schema_module_exec(foo: 'foo') { |foo: | define_method(:foo) { foo } }
      assert_equal('foo', schema.new_jsi({}).foo)
    end
  end

  describe '#subschema error conditions' do
    describe 'the subschema is not a schema' do
      it 'errors with a Base - subschema key is not described' do
        schema = JSI::JSONSchemaOrgDraft07.new_schema({
          'foo' => {},
        })
        err = assert_raises(JSI::Schema::NotASchemaError) do
          schema.subschema(['foo'])
        end
        msg = <<~MSG
          subschema is not a schema at pointer: /foo
          \#{<JSI>}
          MSG
        assert_equal(msg.chomp, err.message)
      end

      it 'errors with a Base - subschema key is described, not a schema' do
        schema = JSI::JSONSchemaOrgDraft07.new_schema({
          'properties' => {},
        })
        err = assert_raises(JSI::Schema::NotASchemaError) do
          schema.subschema(['properties'])
        end
        msg = <<~MSG
          subschema is not a schema at pointer: /properties
          \#{<JSI (JSI::JSONSchemaOrgDraft07.properties["properties"])>}
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end
  end

  describe '#child_applicator_schemas with an object' do
    let(:schema) do
      JSI::JSONSchemaOrgDraft07.new_schema({
        properties: {
          foo: {description: 'foo'},
          baz: {description: 'baz'},
        },
        patternProperties: {
          "^b" => {description: 'b*'},
        },
        additionalProperties: {description: 'whatever'},
      })
    end
    it 'has no subschemas' do
      assert_empty(JSI::JSONSchemaOrgDraft07.new_schema({}).child_applicator_schemas('no', {}))
    end
    it 'has a subschema by property' do
      subschemas = schema.child_applicator_schemas('foo', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, subschemas[0])
      assert_equal('foo', subschemas[0].description)
    end
    it 'has subschemas by patternProperties' do
      subschemas = schema.child_applicator_schemas('bar', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, subschemas[0])
      assert_equal('b*', subschemas[0].description)
    end
    it 'has subschemas by properties, patternProperties' do
      subschemas = schema.child_applicator_schemas('baz', {}).to_a
      assert_equal(2, subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, subschemas[0])
      assert_equal('baz', subschemas[0].description)
      assert_is_a(JSI::JSONSchemaOrgDraft07, subschemas[1])
      assert_equal('b*', subschemas[1].description)
    end
    it 'has subschemas by additional properties' do
      subschemas = schema.child_applicator_schemas('anything', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, subschemas[0])
      assert_equal('whatever', subschemas[0].description)
    end
  end
  describe '#child_applicator_schemas with an array instance' do
    it 'has no subschemas' do
      assert_empty(JSI::JSONSchemaOrgDraft07.new_schema({}).child_applicator_schemas(0, []))
    end
    it 'has a subschema for items' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({
        items: {description: 'items!'}
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, first_subschemas[0])
      assert_equal('items!', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, last_subschemas[0])
      assert_equal('items!', last_subschemas[0].description)
    end
    it 'has a subschema for each item by index' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({
        items: [{description: 'item one'}, {description: 'item two'}]
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, last_subschemas[0])
      assert_equal('item two', last_subschemas[0].description)
    end
    it 'has a subschema by additional items' do
      schema = JSI::JSONSchemaOrgDraft07.new_schema({
        items: [{description: 'item one'}],
        additionalItems: {description: "mo' crap"},
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaOrgDraft07, last_subschemas[0])
      assert_equal("mo' crap", last_subschemas[0].description)
    end
  end
  describe 'stringification' do
    let(:schema) do
      JSI::JSONSchemaOrgDraft06.new_schema({'$id' => 'http://jsi/schema/stringification', type: 'object'})
    end

    it '#inspect' do
      assert_equal("\#{<JSI (JSI::JSONSchemaOrgDraft06) Schema> \"$id\" => \"http://jsi/schema/stringification\", \"type\" => \"object\"}", schema.inspect)
    end
    it '#pretty_print' do
      pp = <<~PP
        \#{<JSI (JSI::JSONSchemaOrgDraft06) Schema>
          "$id" => "http://jsi/schema/stringification",
          "type" => "object"
        }
        PP
      assert_equal(pp, schema.pretty_inspect)
    end
  end
  describe 'validation' do
    let(:schema) { JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'http://jsi/schema/validation', type: 'object'}) }
    describe 'without errors' do
      let(:instance) { {'foo' => 'bar'} }
      it '#instance_validate' do
        result = schema.instance_validate(instance)
        assert_equal(true, result.valid?)
        assert_equal(Set[], result.validation_errors)
        assert_equal(Set[], result.schema_issues)
      end
      it '#instance_valid?' do
        assert_equal(true, schema.instance_valid?(instance))
      end
    end
    describe 'with errors' do
      let(:instance) { ['no'] }
      it '#instance_validate' do
        result = schema.instance_validate(instance)
        assert_equal(false, result.valid?)
        assert_equal(Set[
          JSI::Validation::Error.new({
            :message => "instance type does not match `type` value",
            :keyword => "type",
            :schema => schema,
            :instance_ptr => JSI::Ptr[], :instance_document => ["no"],
          }),
        ], result.validation_errors)
        assert_equal(Set[], result.schema_issues)
      end
      it '#instance_valid?' do
        assert_equal(false, schema.instance_valid?(instance))
      end
    end
  end
end
