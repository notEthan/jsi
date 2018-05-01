require_relative 'test_helper'

describe Scorpio::SchemaObjectBaseArray do
  let(:document) do
    ['foo', true, ['q']]
  end
  let(:path) { [] }
  let(:object) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) do
    {
      'type' => 'array',
      'items' => {},
    }
  end
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:subject) { Scorpio.class_for_schema(schema).new(object) }

  describe 'arraylike []=' do
    it 'sets an index' do
      orig_2 = subject[2]

      subject[2] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject[2].as_json)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['items']), orig_2)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['items']), subject[2])
    end
    it 'updates to a modified copy of the object without altering the original' do
      orig_object = subject.object

      subject[2] = {'y' => 'z'}

      refute_equal(orig_object, subject.object)
      assert_equal(['q'], orig_object[2].as_json)
      assert_equal({'y' => 'z'}, subject.object[2].as_json)
      assert_equal(orig_object.class, subject.object.class)
    end
    describe 'when the object is not arraylike' do
      let(:object) { nil }
      it 'errors' do
        err = assert_raises(NoMethodError) { subject[2] = 0 }
        assert_match(%r(\Aundefined method `\[\]=' for #<Scorpio::SchemaClasses::X.*>\z), err.message)
      end
    end
  end
end
