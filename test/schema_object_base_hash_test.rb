require_relative 'test_helper'

describe Scorpio::SchemaObjectBaseHash do
  let(:document) do
    {'foo' => {'x' => 'y'}}
  end
  let(:path) { [] }
  let(:object) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) do
    {
      'type' => 'object',
      'properties' => {
        'foo' => {'type' => 'object'},
      },
    }
  end
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:subject) { Scorpio.class_for_schema(schema).new(object) }

  describe 'hashlike []=' do
    it 'sets a property' do
      orig_foo = subject['foo']

      subject['foo'] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject['foo'].as_json)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), orig_foo)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject['foo'])
    end
    it 'updates to a modified copy of the object without altering the original' do
      orig_object = subject.object

      subject['foo'] = {'y' => 'z'}

      refute_equal(orig_object, subject.object)
      assert_equal({'x' => 'y'}, orig_object['foo'].as_json)
      assert_equal({'y' => 'z'}, subject.object['foo'].as_json)
      assert_equal(orig_object.class, subject.object.class)
    end
    describe 'when the object is not hashlike' do
      let(:object) { nil }
      it 'errors' do
        err = assert_raises(NoMethodError) { subject['foo'] = 0 }
        assert_match(%r(\Aundefined method `\[\]=' for #<Scorpio::SchemaClasses::X.*>\z), err.message)
      end
    end
  end
end
