require_relative 'test_helper'

describe JSI::Schema do
  describe 'new' do
    it 'initializes from a hash' do
      schema = JSI::Schema.new({'type' => 'object'})
      assert_equal(JSI::JSON::Node.new_doc({'type' => 'object'}), schema.schema_node)
    end
  end
end
