require_relative 'test_helper'

describe JSI::Schema do
  describe 'new_schema' do
    it 'initializes from a hash' do
      schema = JSI.new_schema({'type' => 'object'}, default_metaschema: JSI::JSONSchemaDraft07)
      assert_equal({'type' => 'object'}, schema.jsi_instance)
    end

    it 'cannot instantiate from a non-string $schema' do
      err = assert_raises(ArgumentError) { JSI.new_schema({'$schema' => Object.new}) }
      assert_equal("given schema_content keyword `$schema` is not a string", err.message)
    end

    it '$schema resolves but does not describe schemas' do
      JSI.new_schema({"$schema": "http://json-schema.org/draft-07/schema#", "$id": "tag:guqh"})
      e = assert_raises(JSI::Schema::NotAMetaSchemaError) { JSI.new_schema({"$schema": "tag:guqh"}) }
      assert_equal(%q($schema URI indicates a schema that is not a meta-schema: "tag:guqh"), e.message)
    end

    it 'cannot instantiate from a JSI Schema' do
      err = assert_raises(TypeError) { JSI.new_schema(JSI::JSONSchemaDraft07.new_schema({}), default_metaschema: JSI::JSONSchemaDraft07) }
      assert_equal("Given schema_content is already a JSI::Schema. It cannot be instantiated as the content of a schema.\ngiven: \#{<JSI (JSI::JSONSchemaDraft07) Schema>}", err.message)
    end

    it 'cannot instantiate from a JSI' do
      err = assert_raises(TypeError) { JSI.new_schema(JSI::JSONSchemaDraft07.new_schema({}).new_jsi({}), default_metaschema: JSI::JSONSchemaDraft07) }
      assert_equal("Given schema_content is a JSI::Base. It cannot be instantiated as the content of a schema.\ngiven: \#{<JSI*1>}", err.message)
    end

    it 'instantiates using default_metaschema' do
      # URI
      schema = JSI.new_schema({}, default_metaschema: "http://json-schema.org/draft-07/schema#")
      assert_schemas([JSI::JSONSchemaDraft07.schema], schema)

      # JSI::Schema
      schema = JSI.new_schema({}, default_metaschema: JSI::JSONSchemaDraft07.schema)
      assert_schemas([JSI::JSONSchemaDraft07.schema], schema)

      # invalid: wrong type
      e = assert_raises(TypeError) { JSI.new_schema({}, default_metaschema: 1) }
      assert_match(/default_metaschema.* 1/, e.message)

      # invalid: URI resolves but it's not a meta-schema
      JSI.new_schema({"$schema": "http://json-schema.org/draft-07/schema#", "$id": "tag:l3bu"})
      e = assert_raises(TypeError) { JSI.new_schema({}, default_metaschema: "tag:l3bu") }
      assert_match(/default_metaschema URI.* "tag:l3bu"/, e.message)
    end
  end
  describe('as an instance of meta-schema') do
    let(:metaschema_jsi_module) { JSI::JSONSchemaDraft04 }
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
      assert_nil(JSI::JSONSchemaDraft07.new_schema({}).schema_uri)
    end
    it 'uses a given id ignoring an empty fragment' do
      schema = JSI::JSONSchemaDraft07.new_schema({'$id' => 'http://jsi/schema/given_id_with_fragment#'})
      assert_uri('http://jsi/schema/given_id_with_fragment', schema.schema_uri)
    end
    it 'uses a given id with no fragment' do
      schema = JSI::JSONSchemaDraft07.new_schema({'$id' => 'http://jsi/schema/given_id'})
      assert_uri('http://jsi/schema/given_id', schema.schema_uri)
    end
    it 'uses a pointer in the fragment' do
      schema = JSI::JSONSchemaDraft07.new_schema({
        '$id' => 'http://jsi/schema/uses_pointer_in_fragment#',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_uri('http://jsi/schema/uses_pointer_in_fragment#/properties/foo', subschema.schema_uri)
    end
    it 'uses a pointer in the fragment, ignoring a pointer in the fragment of the root id' do
      schema = JSI::JSONSchemaDraft07.new_schema({
        '$id' => 'http://jsi/schema/id_has_pointer#/notroot',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_uri('http://jsi/schema/id_has_pointer#/properties/foo', subschema.schema_uri)
    end
  end
  describe '#schema_uris' do
    let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07) }
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
        JSI::JSONSchemaDraft06.new_schema(JSON.parse(%q({
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
            # #X collides with anchor in different descendent resource
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
        all_act_uris = all_exp_uris.each_key.map do |uri|
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
        JSI::JSONSchemaDraft04.new_schema(JSON.parse(%q({
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
        all_act_uris = all_exp_uris.each_key.map do |uri|
          subschema = JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(schema)
          {uri => subschema.schema_uris.map(&:to_s)}
        end.inject({}, &:update)
        assert_equal(all_exp_uris, all_act_uris)
      end
    end

    describe 'draft6 example' do
      let(:schema) do
        # from https://datatracker.ietf.org/doc/html/draft-wright-json-schema-01#section-9.2
        JSI::JSONSchemaDraft06.new_schema(JSON.parse(%q({
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
        all_act_uris = all_exp_uris.each_key.map do |uri|
          subschema = JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(schema)
          {uri => subschema.schema_uris.map(&:to_s)}
        end.inject({}, &:update)
        assert_equal(all_exp_uris, all_act_uris)
      end
    end
  end
  describe '#schema_absolute_uri, #anchor' do
    describe 'draft 4' do
      let(:metaschema) { JSI::JSONSchemaDraft04 }
      it "hasn't got one" do
        schema = metaschema.new_schema({})
        assert_nil(schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id with an empty fragment' do
        schema = metaschema.new_schema({'id' => 'http://jsi/test/schema_absolute_uri/d4/empty_fragment#'})
        assert_uri('http://jsi/test/schema_absolute_uri/d4/empty_fragment', schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'id' => 'http://jsi/test/schema_absolute_uri/d4/given_id'})
        assert_uri('http://jsi/test/schema_absolute_uri/d4/given_id', schema.schema_absolute_uri)
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
        assert_uri('http://jsi/test/schema_absolute_uri/d4/nested_w_abs_id', schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id_base',
          'items' => {'id' => 'nested_w_rel_id'},
        })
        assert_uri('http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id', schema.items.schema_absolute_uri)
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
        assert_uri('http://jsi/test/schema_absolute_uri/d4/nested_w_id_frag', schema.items.schema_absolute_uri)
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
          assert_uri('http://jsi/test/d4/external_uri/root_relative', schema.schema_absolute_uri)
          assert_uri('http://jsi/test/d4/external_uri/nested_relative', schema.properties['relative'].schema_absolute_uri)
          assert_uri('http://jsi/test/d4/ignore_external_uri/nested_absolute', schema.properties['absolute'].schema_absolute_uri)
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
      let(:metaschema) { JSI::JSONSchemaDraft06 }
      it "hasn't got one" do
        schema = metaschema.new_schema({})
        assert_nil(schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id with an empty fragment' do
        schema = metaschema.new_schema({'$id' => 'http://jsi/test/schema_absolute_uri/d6/empty_fragment#'})
        assert_uri('http://jsi/test/schema_absolute_uri/d6/empty_fragment', schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'$id' => 'http://jsi/test/schema_absolute_uri/d6/given_id'})
        assert_uri('http://jsi/test/schema_absolute_uri/d6/given_id', schema.schema_absolute_uri)
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
        assert_uri('http://jsi/test/schema_absolute_uri/d6/nested_w_abs_id', schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id_base',
          'items' => {'$id' => 'nested_w_rel_id'},
        })
        assert_uri('http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id', schema.items.schema_absolute_uri)
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
        assert_uri('http://jsi/test/schema_absolute_uri/d6/nested_w_id_frag', schema.items.schema_absolute_uri)
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
          assert_uri('http://jsi/test/d6/external_uri/root_relative', schema.schema_absolute_uri)
          assert_uri('http://jsi/test/d6/external_uri/nested_relative', schema.properties['relative'].schema_absolute_uri)
          assert_uri('http://jsi/test/d6/ignore_external_uri/nested_absolute', schema.properties['absolute'].schema_absolute_uri)
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
        assert_uri('http://jsi/test/schema_absolute_uri/schema.new_base/tehschema', schema.schema_absolute_uri)
      end
    end
  end
  describe '#jsi_schema_module' do
    it 'returns the module for the schema' do
      schema = JSI::JSONSchemaDraft07.new_schema({'$id' => 'http://jsi/schema/jsi_schema_module'})
      assert_is_a(JSI::SchemaModule, schema.jsi_schema_module)
      assert_equal(schema, schema.jsi_schema_module.schema)
    end

    it("is not shared between equal schemas") do
      schema = JSI::JSONSchemaDraft07.new_schema({'title' => 'jsi_schema_module_eq'})
      schema_again = JSI::JSONSchemaDraft07.new_schema({'title' => 'jsi_schema_module_eq'})
      refute_equal(schema.jsi_schema_module, schema_again.jsi_schema_module)
    end

    it("does not create a schema module for a mutable schema") do
      schema = JSI::JSONSchemaDraft07.new_jsi({'$id' => 'tag:4o50'}, mutable: true)
      e = assert_raises(TypeError) { schema.jsi_schema_module }
      assert_equal(%q(mutable schema may not have a schema module: #{<JSI (JSI::JSONSchemaDraft07) Schema> "$id" => "tag:4o50"}), e.message)
    end
  end

  describe '#jsi_schema_module_exec' do
    it 'evaluates the block on the schema module' do
      schema = JSI::JSONSchemaDraft07.new_schema({'id' => 'https://schemas.jsi.unth.net/test/jsi_schema_module_exec'})
      schema.jsi_schema_module_exec(foo: 'foo') { |foo: | define_method(:foo) { foo } }
      assert_equal('foo', schema.new_jsi({}).foo)
    end
  end

  describe '#subschema error conditions' do
    describe 'the subschema is not a schema' do
      it 'errors with a Base - subschema key is not described' do
        schema = JSI::JSONSchemaDraft07.new_schema({
          'foo' => {},
        })
        err = assert_raises(JSI::Schema::NotASchemaError) do
          schema.subschema(['foo'])
        end
        msg = <<~MSG
          subschema is not a schema at pointer: /foo
          \#{<JSI*0>}
          its schemas (which should include a Meta-Schema): JSI::SchemaSet[]
          MSG
        assert_equal(msg.chomp, err.message)
      end

      it 'errors with a Base - subschema key is described, not a schema' do
        schema = JSI::JSONSchemaDraft07.new_schema({
          'properties' => {},
        })
        err = assert_raises(JSI::Schema::NotASchemaError) do
          schema.subschema(['properties'])
        end
        msg = <<~MSG
          subschema is not a schema at pointer: /properties
          \#{<JSI (JSI::JSONSchemaDraft07::Properties)>}
          its schemas (which should include a Meta-Schema): JSI::SchemaSet[
            \#{<JSI:MSN (JSI::JSONSchemaDraft07) Schema>
              "type" => "object",
              "additionalProperties" => \#{<JSI:MSN (JSI::JSONSchemaDraft07) Schema>
                "$ref" => "#"
              },
              "default" => \#{<JSI:MSN (JSI::JSONSchemaDraft07::Default)>}
            }
          ]
          MSG
        assert_equal(msg.chomp, err.message)
      end
    end
  end

  describe '#child_applicator_schemas with an object' do
    let(:schema) do
      JSI::JSONSchemaDraft07.new_schema({
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
      assert_empty(JSI::JSONSchemaDraft07.new_schema({}).child_applicator_schemas('no', {}))
    end
    it 'has a subschema by property' do
      subschemas = schema.child_applicator_schemas('foo', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, subschemas[0])
      assert_equal('foo', subschemas[0].description)
    end
    it 'has subschemas by patternProperties' do
      subschemas = schema.child_applicator_schemas('bar', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, subschemas[0])
      assert_equal('b*', subschemas[0].description)
    end
    it 'has subschemas by properties, patternProperties' do
      subschemas = schema.child_applicator_schemas('baz', {}).to_a
      assert_equal(2, subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, subschemas[0])
      assert_equal('baz', subschemas[0].description)
      assert_is_a(JSI::JSONSchemaDraft07, subschemas[1])
      assert_equal('b*', subschemas[1].description)
    end
    it 'has subschemas by additional properties' do
      subschemas = schema.child_applicator_schemas('anything', {}).to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, subschemas[0])
      assert_equal('whatever', subschemas[0].description)
    end
  end
  describe '#child_applicator_schemas with an array instance' do
    it 'has no subschemas' do
      assert_empty(JSI::JSONSchemaDraft07.new_schema({}).child_applicator_schemas(0, []))
    end
    it 'has a subschema for items' do
      schema = JSI::JSONSchemaDraft07.new_schema({
        items: {description: 'items!'}
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, first_subschemas[0])
      assert_equal('items!', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, last_subschemas[0])
      assert_equal('items!', last_subschemas[0].description)
    end
    it 'has a subschema for each item by index' do
      schema = JSI::JSONSchemaDraft07.new_schema({
        items: [{description: 'item one'}, {description: 'item two'}]
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, last_subschemas[0])
      assert_equal('item two', last_subschemas[0].description)
    end
    it 'has a subschema by additional items' do
      schema = JSI::JSONSchemaDraft07.new_schema({
        items: [{description: 'item one'}],
        additionalItems: {description: "mo' crap"},
      })
      first_subschemas = schema.child_applicator_schemas(0, []).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.child_applicator_schemas(1, []).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::JSONSchemaDraft07, last_subschemas[0])
      assert_equal("mo' crap", last_subschemas[0].description)
    end
  end
  describe 'stringification' do
    let(:schema) do
      JSI.new_schema({
        "$schema": "http://json-schema.org/draft-06/schema",
        "$id": "http://jsi/schema/stringification",
        "type": ["object", "array"],
        "properties": {
          "foo": {
            "items": {"$ref": "#/definitions/no"}
          },
        },
        "items": [
          {"dependencies": {"a": ["b"]}},
          {"dependencies": {"a": {}}},
        ],
        "definitions": {
          "no": {"enum": []}
        }
      })
    end

    it '#inspect' do
      assert_equal(%q(#{<JSI (JSI::JSONSchemaDraft06) Schema> "$schema" => "http://json-schema.org/draft-06/schema", "$id" => "http://jsi/schema/stringification", "type" => #[<JSI (JSI::JSONSchemaDraft06::Type + JSI::JSONSchemaDraft06::Type::Array)> "object", "array"], "properties" => #{<JSI (JSI::JSONSchemaDraft06::Properties)> "foo" => #{<JSI (JSI::JSONSchemaDraft06) Schema> "items" => #{<JSI (JSI::JSONSchemaDraft06 + 1) Schema> "$ref" => "#/definitions/no"}}}, "items" => #[<JSI (JSI::JSONSchemaDraft06::Items + JSI::JSONSchemaDraft06::SchemaArray)> #{<JSI (JSI::JSONSchemaDraft06) Schema> "dependencies" => #{<JSI (JSI::JSONSchemaDraft06::Dependencies)> "a" => #[<JSI (JSI::JSONSchemaDraft06::Dependencies::Dependency + JSI::JSONSchemaDraft06::StringArray)> "b"]}}, #{<JSI (JSI::JSONSchemaDraft06) Schema> "dependencies" => #{<JSI (JSI::JSONSchemaDraft06::Dependencies)> "a" => #{<JSI (JSI::JSONSchemaDraft06 + 1) Schema>}}}], "definitions" => #{<JSI (JSI::JSONSchemaDraft06::Definitions)> "no" => #{<JSI (JSI::JSONSchemaDraft06) Schema> "enum" => #[<JSI (JSI::JSONSchemaDraft06::Enum)>]}}}), schema.inspect)
    end
    it '#pretty_print' do
      pp = <<~PP
        \#{<JSI (JSI::JSONSchemaDraft06) Schema>
          "$schema" => "http://json-schema.org/draft-06/schema",
          "$id" => "http://jsi/schema/stringification",
          "type" => #[<JSI (JSI::JSONSchemaDraft06::Type + JSI::JSONSchemaDraft06::Type::Array)>
            "object",
            "array"
          ],
          "properties" => \#{<JSI (JSI::JSONSchemaDraft06::Properties)>
            "foo" => \#{<JSI (JSI::JSONSchemaDraft06) Schema>
              "items" => \#{<JSI (JSI::JSONSchemaDraft06 + 1) Schema>
                "$ref" => "#/definitions/no"
              }
            }
          },
          "items" => #[<JSI (JSI::JSONSchemaDraft06::Items + JSI::JSONSchemaDraft06::SchemaArray)>
            \#{<JSI (JSI::JSONSchemaDraft06) Schema>
              "dependencies" => \#{<JSI (JSI::JSONSchemaDraft06::Dependencies)>
                "a" => #[<JSI (JSI::JSONSchemaDraft06::Dependencies::Dependency + JSI::JSONSchemaDraft06::StringArray)>
                  "b"
                ]
              }
            },
            \#{<JSI (JSI::JSONSchemaDraft06) Schema>
              "dependencies" => \#{<JSI (JSI::JSONSchemaDraft06::Dependencies)>
                "a" => \#{<JSI (JSI::JSONSchemaDraft06 + 1) Schema>}
              }
            }
          ],
          "definitions" => \#{<JSI (JSI::JSONSchemaDraft06::Definitions)>
            "no" => \#{<JSI (JSI::JSONSchemaDraft06) Schema>
              "enum" => #[<JSI (JSI::JSONSchemaDraft06::Enum)>]
            }
          }
        }
        PP
      assert_equal(pp, schema.pretty_inspect)
    end
  end

  describe 'stringification, thorough for draft 7' do
    let(:recursive_default_child_as_jsi_true) do
      JSI::SimpleWrap::METASCHEMA.new_schema(:recursive_default_child_as_jsi_true) do
        redef_method(:jsi_child_as_jsi_default) { true }
      end
    end

    let(:schema) do
      JSI::SchemaSet[JSI::JSONSchemaDraft07.schema, recursive_default_child_as_jsi_true].new_jsi(YAML.load(<<~YAML
        $schema: "http://json-schema.org/draft-07/schema#"
        description:
          A schema containing each keyword of the meta-schema with valid and invalid type / structure of the keyword value
        definitions:
          "true": true
          "false": false
          empty: {}
          invalid-int: 0
          invalid-array: []
          id: {$id: "tag:test"}
          id-int: {$id: 0}
          schema: {$schema: "tag:test"}
          schema-int: {$schema: 0}
          ref: {$ref: "#"}
          ref-int: {$ref: 0}
          comment: {$comment: "comment"}
          comment-int: {$comment: 0}
          title: {title: "title"}
          title-int: {title: 0}
          description: {description: "description"}
          description-int: {description: 0}
          default: {default: [default]}
          readOnly: {readOnly: true}
          readOnly-int: {readOnly: 0}
          examples: {examples: [{}, x]}
          examples-dict: {examples: {x: 0}}
          multipleOf: {multipleOf: 1}
          multipleOf-ary: {multipleOf: []}
          maximum: {maximum: 0}
          maximum-ary: {maximum: [0]}
          exclusiveMaximum: {exclusiveMaximum: 0}
          exclusiveMaximum-ary: {exclusiveMaximum: [0]}
          minimum: {minimum: 0}
          minimum-ary: {minimum: [0]}
          exclusiveMinimum: {exclusiveMinimum: 0}
          exclusiveMinimum-ary: {exclusiveMinimum: [0]}
          maxLength: {maxLength: 0}
          maxLength-ary: {maxLength: []}
          minLength: {minLength: 0}
          minLength-ary: {minLength: []}
          maxItems: {maxItems: 0}
          maxItems-ary: {maxItems: []}
          minItems: {minItems: 0}
          minItems-ary: {minItems: []}
          maxProperties: {maxProperties: 0}
          maxProperties-ary: {maxProperties: []}
          minProperties: {minProperties: 0}
          minProperties-ary: {minProperties: []}
          pattern: {pattern: "pattern"}
          pattern-int: {pattern: 0}
          additionalItems: {additionalItems: {}}
          additionalItems-int: {additionalItems: 0}
          items: {items: {}}
          items-ary: {items: [{}]}
          items-ary-int: {items: [0]}
          items-int: {items: 0}
          uniqueItems: {uniqueItems: true}
          uniqueItems-int: {uniqueItems: 0}
          contains: {contains: {}}
          contains-int: {contains: 0}
          required: {required: [a]}
          required-ary-int: {required: [0]}
          required-int: {required: 0}
          additionalProperties: {additionalProperties: {}}
          additionalProperties-int: {additionalProperties: 0}
          definitions: {definitions: {definition: {}}}
          definitions-schema-int: {definitions: {definition: 0}}
          definitions-ary: {definitions: [{}]}
          definitions-int: {definitions: 0}
          properties: {properties: {property: {}}}
          properties-schema-int: {properties: {property: 0}}
          properties-ary: {properties: [{}]}
          properties-int: {properties: 0}
          patternProperties: {patternProperties: {patternProperty: {}}}
          patternProperties-schema-int: {patternProperties: {patternProperty: 0}}
          patternProperties-ary: {patternProperties: [{}]}
          patternProperties-int: {patternProperties: 0}
          dependencies: {dependencies: {}}
          dependencies-dep-schema: {dependencies: {s: {}}}
          dependencies-dep-strary: {dependencies: {a: [b]}}
          dependencies-dep-schema+strary: {dependencies: {a: [b], s: {}}}
          dependencies-dep-int: {dependencies: {i: 0}}
          dependencies-dep-schema+strary+int: {dependencies: {s: {}, a: [b], i: 0}}
          dependencies-ary: {dependencies: [{a: {}}]}
          dependencies-int: {dependencies: 0}
          propertyNames: {propertyNames: {}}
          propertyNames-int: {propertyNames: 0}
          const: {const: {}}
          enum: {enum: [{}]}
          enum-int: {enum: 0}
          type: {type: string}
          type-badstr: {type: a}
          type-ary: {type: [string]}
          type-ary-badstr: {type: [a]}
          type-ary-int: {type: [0]}
          type-int: {type: 0}
          format: {format: "format"}
          format-int: {format: 0}
          contentMediaType: {contentMediaType: "contentMediaType"}
          contentMediaType-int: {contentMediaType: 0}
          contentEncoding: {contentEncoding: "contentEncoding"}
          contentEncoding-int: {contentEncoding: 0}
          if: {if: {}}
          if-int: {if: 0}
          then: {then: {}}
          then-int: {then: 0}
          else: {else: {}}
          else-int: {else: 0}
          allOf: {allOf: [{}]}
          allOf-ary-int: {allOf: [0]}
          allOf-int: {allOf: 0}
          anyOf: {anyOf: [{}]}
          anyOf-ary-int: {anyOf: [0]}
          anyOf-int: {anyOf: 0}
          oneOf: {oneOf: [{}]}
          oneOf-ary-int: {oneOf: [0]}
          oneOf-int: {oneOf: 0}
          not: {not: {}}
          not-int: {not: 0}
        YAML
      ))
    end

    it '#pretty_print' do
      pppath = JSI::TEST_RESOURCES_PATH.join('schema.thorough.pretty_print')
      if ENV['JSI_TEST_REGEN']
        pppath.write(schema.pretty_inspect)
      end
      assert_equal(pppath.read, schema.pretty_inspect)
    end
  end

  describe 'validation' do
    let(:schema) { JSI::JSONSchemaDraft07.new_schema({'$id' => 'http://jsi/schema/validation', type: 'object'}) }
    describe 'without errors' do
      let(:instance) { {'foo' => 'bar'} }
      it '#instance_validate' do
        result = schema.instance_validate(instance)
        assert_equal(true, result.valid?)
        assert_equal(Set[], result.immediate_validation_errors)
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
            :additional => {},
            :schema => schema,
            :instance_ptr => JSI::Ptr[], :instance_document => ["no"],
            :child_errors => Set[],
          }),
        ], result.immediate_validation_errors)
      end
      it '#instance_valid?' do
        assert_equal(false, schema.instance_valid?(instance))
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
