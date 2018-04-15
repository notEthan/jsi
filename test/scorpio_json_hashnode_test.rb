require_relative 'test_helper'

describe Scorpio::JSON::HashNode do
  # document of the node being tested
  let(:document) { {'a' => 'b', 'c' => {'d' => 'e'}} }
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
      assert_instance_of(Scorpio::JSON::HashNode, node['c'])
      assert_equal([['a', 'b'], ['c', node['c']]], out)
    end
    it 'iterates, two arguments' do
      out = []
      retval = node.each do |k, v|
        out << [k, v]
      end
      assert_instance_of(Scorpio::JSON::HashNode, node['c'])
      assert_equal([['a', 'b'], ['c', node['c']]], out)
    end
    it 'returns self' do
      assert_equal(node.each { }.object_id, node.object_id)
    end
    it 'returns an enumerator when called with no block' do
      enum = node.each
      assert_instance_of(Enumerator, enum)
      assert_equal([['a', 'b'], ['c', node['c']]], enum.to_a)
    end
  end
  describe '#to_hash' do
    it 'returns a Hash with Nodes in' do
      assert_instance_of(Hash, node.to_hash)
      assert_equal({'a' => 'b', 'c' => node['c']}, node.to_hash)
    end
  end
  describe '#merge' do
    let(:document) { {'a' => {'b' => 0}, 'c' => {'d' => 'e'}} }
    # testing the node at 'c' here, merging a hash at a path within a document.
    let(:path) { ['c'] }
    it 'merges' do
      merged = node.merge('x' => 'y')
      # check the content at 'c' was merged with the remainder of the document intact (at 'a')
      assert_equal({'a' => {'b' => 0}, 'c' => {'d' => 'e', 'x' => 'y'}}, merged.document)
      # check the original node retains its original document
      assert_equal({'a' => {'b' => 0}, 'c' => {'d' => 'e'}}, node.document)
      # check that unnecessary copies of unaffected parts of the document were not made
      assert_equal(node.document['a'].object_id, merged.document['a'].object_id)
    end
  end
  # these methods just delegate to Hash so not going to test excessively
  describe 'key only methods' do
    it('#each_key') { assert_equal(['a', 'c'], node.each_key.to_a) }
  end
  describe 'key + value methods' do
    it('#any?') { assert_equal(true, node.any? { |k, v| k == 'a' }) }
  end
end
