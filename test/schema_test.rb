require_relative 'test_helper'

describe JSI::Schema do
  describe 'new' do
    it 'initializes from a hash' do
      schema = JSI::Schema.new({'type' => 'object'})
      assert_equal({'type' => 'object'}, schema.jsi_instance)
    end
    it 'initializes from a Node' do
      schema_node = JSI::JSON::Node.new_doc({'type' => 'object'})
      schema = JSI::Schema.new(schema_node)
      assert_equal(schema_node, schema.jsi_instance)
    end
    it 'cannot instantiate from some unknown object' do
      err = assert_raises(TypeError) { JSI::Schema.new(Object.new) }
      assert_match(/\Acannot instantiate Schema from: #<Object:.*>\z/m, err.message)
    end
    it 'instantiating a schema from schema returns that schema' do
      # this is kinda dumb, but Schema.new now just aliases Schema.from_object, so this is the behavior
      assert_equal(JSI::Schema.new({}), JSI::Schema.new(JSI::Schema.new({})))
    end
  end
  describe 'as an instance of metaschema' do
    let(:metaschema_jsi_module) { JSI::JSONSchemaOrgDraft04 }
    let(:schema_object) { {'type' => 'array', 'items' => {'description' => 'items!'}} }
    let(:schema) { metaschema_jsi_module.new_jsi(schema_object) }
    it '#[]' do
      schema_items = schema['items']
      assert_is_a(metaschema_jsi_module, schema_items)
      assert_equal({'description' => 'items!'}, schema_items.as_json)
    end
  end
  describe '#schema_id' do
    it "hasn't got one" do
      assert_nil(JSI::Schema.new({}).schema_id)
    end
    it 'uses a given id with a fragment' do
      schema = JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/given_id#'})
      assert_equal('https://schemas.jsi.unth.net/test/given_id#', schema.schema_id)
    end
    it 'uses a given id (adding a fragment)' do
      schema = JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/given_id'})
      assert_equal('https://schemas.jsi.unth.net/test/given_id#', schema.schema_id)
    end
    it 'uses a pointer in the fragment' do
      schema = JSI::Schema.new({
        'id' => 'https://schemas.jsi.unth.net/test/given_id#',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('https://schemas.jsi.unth.net/test/given_id#/properties/foo', subschema.schema_id)
    end
    it 'uses a pointer in the fragment relative to the fragment of the root' do
      schema = JSI::Schema.new({
        'id' => 'https://schemas.jsi.unth.net/test/given_id#/notroot',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      subschema = schema['properties']['foo']
      assert_equal('https://schemas.jsi.unth.net/test/given_id#/notroot/properties/foo', subschema.schema_id)
    end
  end
  describe '#schema_ids' do
    let(:schema_object) do
      {
        "$id": "https://example.com/foo",
        "items": {
          "$id": "https://example.com/bar",
          "additionalProperties": { }
        }
      }
    end
    let(:schema) { JSI::Schema.new(schema_object) }
    it 'has both ids' do
      assert_equal([
        "https://example.com/bar#",
        "https://example.com/foo#/items"
      ], schema.items.schema_ids)
    end
  end
  describe '#jsi_schema_module' do
    it 'returns the module for the schema' do
      schema = JSI::Schema.new({'id' => 'https://schemas.jsi.unth.net/test/jsi_schema_module'})
      assert_is_a(JSI::SchemaModule, schema.jsi_schema_module)
      assert_equal(schema, schema.jsi_schema_module.schema)
    end
  end
  describe '#jsi_schema_class' do
    it 'returns the class for the schema' do
      schema = JSI::Schema.new({'id' => 'https://schemas.jsi.unth.net/test/schema_schema_class'})
      assert_equal(JSI.class_for_schemas([schema]), schema.jsi_schema_class)
    end
  end
  describe '#subschemas_for_property' do
    let(:schema) do
      JSI::Schema.new({
        properties: {
          foo: {description: 'foo'},
          baz: {description: 'baz'},
        },
        patternProperties: {
          "^b" => {description: 'ba*'},
        },
        additionalProperties: {description: 'whatever'},
      })
    end
    it 'has no subschemas' do
      assert_empty(JSI::Schema.new({}).subschemas_for_property('no'))
    end
    it 'has a subschema by property' do
      subschemas = schema.subschemas_for_property('foo')
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('foo', subschemas[0].description)
    end
    it 'has subschemas by patternProperties' do
      subschemas = schema.subschemas_for_property('bar')
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('ba*', subschemas[0].description)
    end
    it 'has subschemas by properties, patternProperties' do
      subschemas = schema.subschemas_for_property('baz')
      assert_equal(2, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('baz', subschemas[0].description)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[1])
      assert_equal('ba*', subschemas[1].description)
    end
    it 'has subschemas by additional properties' do
      subschemas = schema.subschemas_for_property('anything')
      assert_equal(1, subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, subschemas[0])
      assert_equal('whatever', subschemas[0].description)
    end
  end
  describe '#subschemas_for_index' do
    it 'has no subschemas' do
      assert_empty(JSI::Schema.new({}).subschemas_for_index(0))
    end
    it 'has a subschema for items' do
      schema = JSI::Schema.new({
        items: {description: 'items!'}
      })
      first_subschemas = schema.subschemas_for_index(0)
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('items!', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1)
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal('items!', last_subschemas[0].description)
    end
    it 'has a subschema for each item by index' do
      schema = JSI::Schema.new({
        items: [{description: 'item one'}, {description: 'item two'}]
      })
      first_subschemas = schema.subschemas_for_index(0)
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1)
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal('item two', last_subschemas[0].description)
    end
    it 'has a subschema by additional items' do
      schema = JSI::Schema.new({
        items: [{description: 'item one'}],
        additionalItems: {description: "mo' crap"},
      })
      first_subschemas = schema.subschemas_for_index(0)
      assert_equal(1, first_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, first_subschemas[0])
      assert_equal('item one', first_subschemas[0].description)
      last_subschemas = schema.subschemas_for_index(1)
      assert_equal(1, last_subschemas.size)
      assert_is_a(JSI::Schema.default_metaschema.jsi_schema_module, last_subschemas[0])
      assert_equal("mo' crap", last_subschemas[0].description)
    end
  end
  describe 'stringification' do
    let(:schema) do
      JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/stringification', type: 'object'})
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
    let(:schema) { JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/validation', type: 'object'}) }
    describe 'without errors' do
      let(:instance) { {'foo' => 'bar'} }
      it '#validate_instance' do
        result = schema.validate_instance(instance)
        assert_equal(true, result.valid?)
        assert_equal(Set[], result.validation_errors)
        assert_equal(Set[], result.annotations)
        assert_equal(Set[], result.schema_errors)
      end
      it '#instance_valid?' do
        assert_equal(true, schema.instance_valid?(instance))
      end
    end
    describe 'with errors' do
      let(:instance) { ['no'] }
      it '#validate_instance' do
        result = schema.validate_instance(instance)
        assert_equal(false, result.valid?)
        assert_equal(Set[
          {
            :message => "instance type does not match `type` value",
            :keyword => "type",
            :schema_ptr => JSI::SchemaPointer[], :schema_document => schema.jsi_document,
            :instance_ptr => JSI::JSON::Pointer[], :instance_document => ["no"],
          },
        ], result.validation_errors)
        assert_equal(Set[], result.annotations)
        assert_equal(Set[], result.schema_errors)
      end
      it '#instance_valid?' do
        assert_equal(false, schema.instance_valid?(instance))
      end
    end
  end
end
