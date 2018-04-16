require_relative 'test_helper'

describe Scorpio::JSON::ArrayNode do
  # document of the node being tested
  let(:document) { ['a', ['b', 'q'], {'c' => {'d' => 'e'}}] }
  # by default the node is the whole document
  let(:path) { [] }
  # the node being tested
  let(:node) { Scorpio::JSON::Node.new_by_type(document, path) }

  describe '#each' do
    it 'iterates, one argument' do
      out = []
      node.each do |arg|
        out << arg
      end
      assert_instance_of(Scorpio::JSON::ArrayNode, node[1])
      assert_instance_of(Scorpio::JSON::HashNode, node[2])
      assert_equal(['a', node[1], node[2]], out)
    end
    it 'returns self' do
      assert_equal(node.each { }.object_id, node.object_id)
    end
    it 'returns an enumerator when called with no block' do
      enum = node.each
      assert_instance_of(Enumerator, enum)
      assert_equal(['a', node[1], node[2]], enum.to_a)
    end
  end
  describe '#to_ary' do
    it 'returns a Array with Nodes in' do
      assert_instance_of(Array, node.to_ary)
      assert_equal(['a', node[1], node[2]], node.to_ary)
    end
  end
end
