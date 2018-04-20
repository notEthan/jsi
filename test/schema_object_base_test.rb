require_relative 'test_helper'

describe Scorpio::SchemaObjectBase do
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({}, [])).new({'a' => 'b'}).as_json)
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({'type' => 'object'}, [])).new({'a' => 'b'}).as_json)
      assert_equal(['a', 'b'], Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({'type' => 'array'}, [])).new(['a', 'b']).as_json)
    end
  end
end
