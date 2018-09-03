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
end
