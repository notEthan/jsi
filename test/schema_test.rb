require_relative 'test_helper'

describe JSI::Schema do
  describe 'new' do
    it 'initializes from a hash' do
      schema = JSI::Schema.new({'type' => 'object'})
      assert_equal({'type' => 'object'}, schema.instance)
    end
    it 'initializes from a Node' do
      schema_node = JSI::JSON::Node.new_doc({'type' => 'object'})
      schema = JSI::Schema.new(schema_node)
      assert_equal(schema_node, schema.instance)
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
    let(:metaschema_jsi_class) { JSI::JSONSchemaOrgDraft04 }
    let(:schema_object) { {'type' => 'array', 'items' => {'description' => 'items!'}} }
    let(:schema) { metaschema_jsi_class.new(schema_object) }
    it '#[]' do
      schema_items = schema['items']
      assert_instance_of(metaschema_jsi_class, schema_items)
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
  describe '#jsi_schema_module' do
    it 'returns the module for the schema' do
      schema = JSI::Schema.new({'id' => 'https://schemas.jsi.unth.net/test/jsi_schema_module'})
      assert_equal(schema, schema.jsi_schema_module.schema)
    end
  end
  describe '#schema_class' do
    it 'returns the class for the schema' do
      schema = JSI::Schema.new({'id' => 'https://schemas.jsi.unth.net/test/schema_schema_class'})
      assert_equal(JSI.class_for_schema(schema), schema.schema_class)
    end
  end
  describe '#subschema_for_property' do
    let(:schema) do
      JSI::Schema.new({
        properties: {foo: {description: 'foo'}},
        patternProperties: {"^ba" => {description: 'ba*'}},
        additionalProperties: {description: 'whatever'},
      })
    end
    it 'has no subschema' do
      assert_equal(nil, JSI::Schema.new({}).subschema_for_property('no'))
    end
    it 'has a subschema by property' do
      subschema = schema.subschema_for_property('foo')
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, subschema)
      assert_equal('foo', subschema['description'])
    end
    it 'has a subschema by pattern property' do
      subschema = schema.subschema_for_property('bar')
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, subschema)
      assert_equal('ba*', subschema['description'])
    end
    it 'has a subschema by additional properties' do
      subschema = schema.subschema_for_property('anything')
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, subschema)
      assert_equal('whatever', subschema['description'])
    end
  end
  describe '#subschema_for_index' do
    it 'has no subschema' do
      assert_equal(nil, JSI::Schema.new({}).subschema_for_index(0))
    end
    it 'has a subschema for items' do
      schema = JSI::Schema.new({
        items: {description: 'items!'}
      })
      first_subschema = schema.subschema_for_index(0)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, first_subschema)
      assert_equal('items!', first_subschema['description'])
      last_subschema = schema.subschema_for_index(1)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, last_subschema)
      assert_equal('items!', last_subschema['description'])
    end
    it 'has a subschema for each item by index' do
      schema = JSI::Schema.new({
        items: [{description: 'item one'}, {description: 'item two'}]
      })
      first_subschema = schema.subschema_for_index(0)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, first_subschema)
      assert_equal('item one', first_subschema['description'])
      last_subschema = schema.subschema_for_index(1)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, last_subschema)
      assert_equal('item two', last_subschema['description'])
    end
    it 'has a subschema by additional items' do
      schema = JSI::Schema.new({
        items: [{description: 'item one'}],
        additionalItems: {description: "mo' crap"},
      })
      first_subschema = schema.subschema_for_index(0)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, first_subschema)
      assert_equal('item one', first_subschema['description'])
      last_subschema = schema.subschema_for_index(1)
      assert_instance_of(JSI::Schema.default_metaschema.jsi_schema_class, last_subschema)
      assert_equal("mo' crap", last_subschema['description'])
    end
  end
  describe 'stringification' do
    let(:schema) do
      JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/stringification', type: 'object'})
    end

    it '#inspect' do
      assert_equal("\#{<JSI::JSONSchemaOrgDraft06 Hash> \"id\" => \"https://schemas.jsi.unth.net/test/stringification\", \"type\" => \"object\"}", schema.inspect)
    end
    it '#pretty_print' do
      assert_equal("\#{<JSI::JSONSchemaOrgDraft06 Hash>
        \"id\" => \"https://schemas.jsi.unth.net/test/stringification\",
        \"type\" => \"object\"
      }".gsub(/^      /, ''), schema.pretty_inspect.chomp)
    end
  end
  describe 'validation' do
    let(:schema) { JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/validation', type: 'object'}) }
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
