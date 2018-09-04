require_relative 'test_helper'

SomeMetaschema = JSI.class_for_schema({id: 'https://schemas.jsi.unth.net/test/somemetaschema', type: 'object'})

describe JSI::Schema do
  describe 'new' do
    it 'initializes from a hash' do
      schema = JSI::Schema.new({'type' => 'object'})
      assert_equal(JSI::JSON::Node.new_doc({'type' => 'object'}), schema.schema_node)
    end
    it 'initializes from a Node' do
      schema_node = JSI::JSON::Node.new_doc({'type' => 'object'})
      schema = JSI::Schema.new(schema_node)
      assert_equal(schema_node, schema.schema_node)
      assert_equal(schema_node, schema.schema_object)
    end
    it 'initializes from a JSI' do
      schema_jsi = SomeMetaschema.new('type' => 'object')
      schema = JSI::Schema.new(schema_jsi)
      assert_equal(schema_jsi.instance, schema.schema_node)
      assert_equal(schema_jsi, schema.schema_object)
    end
    it 'cannot instantiate from some unknown object' do
      err = assert_raises(TypeError) { JSI::Schema.new(Object.new) }
      assert_match(/\Acannot instantiate Schema from: #<Object:.*>\z/m, err.message)
    end
    it 'makes no sense to instantiate schema from schema' do
      err = assert_raises(TypeError) { JSI::Schema.new(JSI::Schema.new({})) }
      assert_match(/\Awill not instantiate Schema from another Schema: #<JSI::Schema schema_id=.*>\z/m, err.message)
    end
  end
  describe 'as an instance of metaschema' do
    let(:default_metaschema) do
      validator = ::JSON::Validator.default_validator
      metaschema_file = validator.metaschema
      JSI::Schema.new(::JSON.parse(File.read(metaschema_file)))
    end
    let(:metaschema_jsi_class) { JSI.class_for_schema(default_metaschema) }
    let(:schema_object) { {'type' => 'array', 'items' => {'description' => 'items!'}} }
    let(:schema_jsi) { metaschema_jsi_class.new(schema_object) }
    let(:schema) { JSI::Schema.new(schema_jsi) }
    it '#[]' do
      schema_items = schema['items']
      assert_instance_of(metaschema_jsi_class, schema_items)
      assert_equal({'description' => 'items!'}, schema_items.as_json)
    end
  end
  describe '#schema_id' do
    it 'generates one' do
      assert_match(/\A[0-9a-f\-]+#\z/, JSI::Schema.new({}).schema_id)
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
      schema_node = JSI::JSON::Node.new_doc({
        'id' => 'https://schemas.jsi.unth.net/test/given_id#',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      schema = JSI::Schema.new(schema_node['properties']['foo'])
      assert_equal('https://schemas.jsi.unth.net/test/given_id#/properties/foo', schema.schema_id)
    end
    it 'uses a pointer in the fragment relative to the fragment of the root' do
      schema_node = JSI::JSON::Node.new_doc({
        'id' => 'https://schemas.jsi.unth.net/test/given_id#/notroot',
        'properties' => {'foo' => {'type' => 'object'}},
      })
      schema = JSI::Schema.new(schema_node['properties']['foo'])
      assert_equal('https://schemas.jsi.unth.net/test/given_id#/notroot/properties/foo', schema.schema_id)
    end
  end
  describe '#schema_class' do
    it 'returns the class for the schema' do
      schema_node = JSI::JSON::Node.new_doc({'id' => 'https://schemas.jsi.unth.net/test/schema_schema_class'})
      assert_equal(JSI.class_for_schema(schema_node), JSI::Schema.new(schema_node).schema_class)
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
      assert_instance_of(JSI::Schema, subschema)
      assert_equal('foo', subschema['description'])
    end
    it 'has a subschema by pattern property' do
      subschema = schema.subschema_for_property('bar')
      assert_instance_of(JSI::Schema, subschema)
      assert_equal('ba*', subschema['description'])
    end
    it 'has a subschema by additional properties' do
      subschema = schema.subschema_for_property('anything')
      assert_instance_of(JSI::Schema, subschema)
      assert_equal('whatever', subschema['description'])
    end
  end
end
