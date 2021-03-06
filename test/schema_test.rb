require_relative 'test_helper'

describe JSI::Schema do
  describe 'new_schema' do
    it 'initializes from a hash' do
      schema = JSI.new_schema({'type' => 'object'})
      assert_equal({'type' => 'object'}, schema.jsi_instance)
    end
    it 'cannot instantiate from some unknown object' do
      err = assert_raises(TypeError) { JSI.new_schema(Object.new) }
      assert_match(/\Acannot instantiate Schema from: #<Object:.*>\z/m, err.message)
    end
    it 'instantiating a schema from a schema returns that schema' do
      assert_equal(JSI.new_schema({}), JSI.new_schema(JSI.new_schema({})))
    end
  end
  describe 'as an instance of metaschema' do
    let(:metaschema_jsi_module) { JSI::JSONSchemaOrgDraft04 }
    let(:schema_content) { {'type' => 'array', 'items' => {'description' => 'items!'}} }
    let(:schema) { metaschema_jsi_module.new_jsi(schema_content) }
    it '#[]' do
      schema_items = schema['items']
      assert_is_a(metaschema_jsi_module, schema_items)
      assert_equal({'description' => 'items!'}, schema_items.as_json)
    end
  end
  describe '#schema_id' do
    it "hasn't got one" do
      assert_nil(JSI.new_schema({}).schema_id)
    end
    it 'uses a given id with a fragment' do
      schema = JSI.new_schema({'id' => 'https://schemas.jsi.unth.net/test/given_id_with_fragment#'})
      assert_equal('https://schemas.jsi.unth.net/test/given_id_with_fragment#', schema.schema_id)
    end
    it 'uses a given id (adding a fragment)' do
      schema = JSI.new_schema({id: 'https://schemas.jsi.unth.net/test/given_id'})
      assert_equal('https://schemas.jsi.unth.net/test/given_id#', schema.schema_id)
    end
    it 'uses a pointer in the fragment' do
      schema = JSI.new_schema({
        'id' => 'https://schemas.jsi.unth.net/test/uses_pointer_in_fragment#',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('https://schemas.jsi.unth.net/test/uses_pointer_in_fragment#/properties/foo', subschema.schema_id)
    end
    it 'uses a pointer in the fragment relative to the fragment of the root' do
      schema = JSI.new_schema({
        'id' => 'https://schemas.jsi.unth.net/test/id_has_pointer#/notroot',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('https://schemas.jsi.unth.net/test/id_has_pointer#/notroot/properties/foo', subschema.schema_id)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d4/empty_fragment'), schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'id' => 'http://jsi/test/schema_absolute_uri/d4/given_id'})
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d4/given_id'), schema.schema_absolute_uri)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d4/nested_w_abs_id'), schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          'id' => 'http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id_base',
          'items' => {'id' => 'nested_w_rel_id'},
        })
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d4/nested_w_rel_id'), schema.items.schema_absolute_uri)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d4/nested_w_id_frag'), schema.items.schema_absolute_uri)
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
      describe 'externally supplied base uri' do
        it 'schema with relative ids' do
          schema = metaschema.new_schema({
            'id' => 'root_relative',
            'properties' => {
              'relative' => {'id' => 'nested_relative'},
              'absolute' => {'id' => 'http://jsi/test/d4/ignore_external_base_uri/nested_absolute'},
              'none' => {},
            },
          }, base_uri: 'http://jsi/test/d4/external_base_uri/1')
          assert_equal(Addressable::URI.parse('http://jsi/test/d4/external_base_uri/root_relative'), schema.schema_absolute_uri)
          assert_equal(Addressable::URI.parse('http://jsi/test/d4/external_base_uri/nested_relative'), schema.properties['relative'].schema_absolute_uri)
          assert_equal(Addressable::URI.parse('http://jsi/test/d4/ignore_external_base_uri/nested_absolute'), schema.properties['absolute'].schema_absolute_uri)
          assert_nil(schema.properties['none'].schema_absolute_uri)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d6/empty_fragment'), schema.schema_absolute_uri)
        assert_nil(schema.anchor)
      end
      it 'uses a given id without a fragment' do
        schema = metaschema.new_schema({'$id' => 'http://jsi/test/schema_absolute_uri/d6/given_id'})
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d6/given_id'), schema.schema_absolute_uri)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d6/nested_w_abs_id'), schema.items.schema_absolute_uri)
        assert_nil(schema.items.anchor)
      end
      it 'nested schema with relative id' do
        schema = metaschema.new_schema({
          '$id' => 'http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id_base',
          'items' => {'$id' => 'nested_w_rel_id'},
        })
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d6/nested_w_rel_id'), schema.items.schema_absolute_uri)
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
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/d6/nested_w_id_frag'), schema.items.schema_absolute_uri)
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
      describe 'externally supplied base uri' do
        it 'schema with relative ids' do
          schema = metaschema.new_schema({
            '$id' => 'root_relative',
            'properties' => {
              'relative' => {'$id' => 'nested_relative'},
              'absolute' => {'$id' => 'http://jsi/test/d6/ignore_external_base_uri/nested_absolute'},
              'none' => {},
            },
          }, base_uri: 'http://jsi/test/d6/external_base_uri/0')
          assert_equal(Addressable::URI.parse('http://jsi/test/d6/external_base_uri/root_relative'), schema.schema_absolute_uri)
          assert_equal(Addressable::URI.parse('http://jsi/test/d6/external_base_uri/nested_relative'), schema.properties['relative'].schema_absolute_uri)
          assert_equal(Addressable::URI.parse('http://jsi/test/d6/ignore_external_base_uri/nested_absolute'), schema.properties['absolute'].schema_absolute_uri)
          assert_nil(schema.properties['none'].schema_absolute_uri)
        end
      end
    end
    describe 'externally supplied base uri with JSI.new_schema' do
      it 'resolves' do
        schema = JSI.new_schema({'$id' => 'tehschema'}, base_uri: 'http://jsi/test/schema_absolute_uri/schema.new_base/0')
        assert_equal(Addressable::URI.parse('http://jsi/test/schema_absolute_uri/schema.new_base/tehschema'), schema.schema_absolute_uri)
      end
    end
  end
  describe '#jsi_schema_module' do
    it 'returns the module for the schema' do
      schema = JSI.new_schema({'id' => 'https://schemas.jsi.unth.net/test/jsi_schema_module'})
      assert_is_a(JSI::SchemaModule, schema.jsi_schema_module)
      assert_equal(schema, schema.jsi_schema_module.schema)
    end
  end
  describe '#jsi_schema_class' do
    it 'returns the class for the schema' do
      schema = JSI.new_schema({'id' => 'https://schemas.jsi.unth.net/test/schema_schema_class'})
      assert_equal(JSI.class_for_schemas([schema]), schema.jsi_schema_class)
    end
  end
  describe '#subschemas_for_property_name' do
    let(:schema) do
      JSI.new_schema({
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
      assert_empty(JSI.new_schema({}).subschemas_for_property_name('no'))
    end
    it 'has a subschema by property' do
      subschemas = schema.subschemas_for_property_name('foo').to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('foo', subschemas[0].description)
    end
    it 'has subschemas by patternProperties' do
      subschemas = schema.subschemas_for_property_name('bar').to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('b*', subschemas[0].description)
    end
    it 'has subschemas by properties, patternProperties' do
      subschemas = schema.subschemas_for_property_name('baz').to_a
      assert_equal(2, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('baz', subschemas[0].description)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[1])
      assert_equal('b*', subschemas[1].description)
    end
    it 'has subschemas by additional properties' do
      subschemas = schema.subschemas_for_property_name('anything').to_a
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('whatever', subschemas[0].description)
    end
  end
  describe '#subschemas_for_index' do
    it 'has no subschemas' do
      assert_empty(JSI.new_schema({}).subschemas_for_index(0))
    end
    it 'has a subschema for items' do
      schema = JSI.new_schema({
        items: {description: 'items!'}
      })
      first_subschemas = schema.subschemas_for_index(0).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('items!', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal('items!', last_subschemas[0].description)
    end
    it 'has a subschema for each item by index' do
      schema = JSI.new_schema({
        items: [{description: 'item one'}, {description: 'item two'}]
      })
      first_subschemas = schema.subschemas_for_index(0).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal('item two', last_subschemas[0].description)
    end
    it 'has a subschema by additional items' do
      schema = JSI.new_schema({
        items: [{description: 'item one'}],
        additionalItems: {description: "mo' crap"},
      })
      first_subschemas = schema.subschemas_for_index(0).to_a
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1).to_a
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal("mo' crap", last_subschemas[0].description)
    end
  end
  describe 'stringification' do
    let(:schema) do
      JSI.new_schema({id: 'https://schemas.jsi.unth.net/test/stringification', type: 'object'})
    end

    it '#inspect' do
      assert_equal("\#{<JSI (JSI::JSONSchemaOrgDraft06) Schema> \"id\" => \"https://schemas.jsi.unth.net/test/stringification\", \"type\" => \"object\"}", schema.inspect)
    end
    it '#pretty_print' do
      assert_equal("\#{<JSI (JSI::JSONSchemaOrgDraft06) Schema>
        \"id\" => \"https://schemas.jsi.unth.net/test/stringification\",
        \"type\" => \"object\"
      }".gsub(/^      /, ''), schema.pretty_inspect.chomp)
    end
  end
  describe 'validation' do
    let(:schema) { JSI.new_schema({id: 'https://schemas.jsi.unth.net/test/validation', type: 'object'}) }
    describe 'without errors' do
      let(:instance) { {'foo' => 'bar'} }
      it '#fully_validate_instance' do
        assert_equal([], schema.fully_validate_instance(instance))
      end
      it '#validate_instance' do
        assert_equal(true, schema.validate_instance(instance))
      end
      it '#validate_instance!' do
        assert_equal(true, schema.validate_instance!(instance))
      end
    end
    describe 'with errors' do
      let(:instance) { ['no'] }
      it '#fully_validate_instance' do
        assert_equal(["The property '#/' of type array did not match the following type: object in schema https://schemas.jsi.unth.net/test/validation"], schema.fully_validate_instance(instance))
      end
      it '#validate_instance' do
        assert_equal(false, schema.validate_instance(instance))
      end
      it '#validate_instance!' do
        err = assert_raises(JSON::Schema::ValidationError) do
          schema.validate_instance!(instance)
        end
        assert_equal("The property '#/' of type array did not match the following type: object", err.message)
      end
    end
  end
end
