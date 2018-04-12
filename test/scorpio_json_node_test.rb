require_relative 'test_helper'

describe Scorpio::JSON::Node do
  describe 'initialization' do
    it 'initializes' do
      node = Scorpio::JSON::Node.new({'a' => 'b'}, [])
      assert_equal({'a' => 'b'}, node.document)
      assert_equal([], node.path)
    end
  end
  describe 'initialization by .new_by_type' do
    it 'initializes HashNode' do
      node = Scorpio::JSON::Node.new_by_type({'a' => 'b'}, [])
      assert_instance_of(Scorpio::JSON::HashNode, node)
      assert_equal({'a' => 'b'}, node.document)
    end
    it 'initializes ArrayNode' do
      node = Scorpio::JSON::Node.new_by_type(['a', 'b'], [])
      assert_instance_of(Scorpio::JSON::ArrayNode, node)
      assert_equal(['a', 'b'], node.document)
    end
    it 'initializes Node' do
      object = Object.new
      node = Scorpio::JSON::Node.new_by_type(object, [])
      assert_instance_of(Scorpio::JSON::Node, node)
      assert_equal(object, node.document)
    end
  end
  describe '#pointer' do
    it 'is a ::JSON::Schema::Pointer' do
      assert_instance_of(::JSON::Schema::Pointer, Scorpio::JSON::Node.new({}, []).pointer)
    end
  end
  describe '#content' do
    it 'returns the content at the root' do
      assert_equal({'a' => 'b'}, Scorpio::JSON::Node.new({'a' => 'b'}, []).content)
    end
    it 'returns the content from the deep' do
      assert_equal('b', Scorpio::JSON::Node.new([0, {'x' => [{'a' => ['b']}]}], [1, 'x', 0, 'a', 0]).content)
    end
  end
  describe '#[]' do
    describe 'without dereferencing' do
      let(:node) { Scorpio::JSON::Node.new([0, {'x' => [{'a' => ['b']}]}], []) }
      it 'subscripts arrays and hashes' do
        assert_equal('b', node[1]['x'][0]['a'][0])
      end
      it 'returns ArrayNode for an array' do
        subscripted = node[1]['x']
        assert_instance_of(Scorpio::JSON::ArrayNode, subscripted)
        assert_equal([{'a' => ['b']}], subscripted.content)
        assert_equal([1, 'x'], subscripted.path)
      end
      it 'returns HashNode for a Hash' do
        subscripted = node[1]
        assert_instance_of(Scorpio::JSON::HashNode, subscripted)
        assert_equal({'x' => [{'a' => ['b']}]}, subscripted.content)
        assert_equal([1], subscripted.path)
      end
    end
    describe 'with dereferencing' do
      let(:document) do
        {
          'foo' => {'bar' => ['baz']},
          'a' => {'$ref' => '#/foo', 'description' => 'hi'}, # not sure a description is actually allowed here, whatever
        }
      end
      let(:node) { Scorpio::JSON::Node.new(document, []) }
      it 'subscripts a node consisting of a $ref WITHOUT following' do
        subscripted = node['a']
        assert_equal({'$ref' => '#/foo', 'description' => 'hi'}, subscripted.content)
        assert_equal(['a'], subscripted.path)
      end
      it 'follows a $ref when subscripting past it' do
        subscripted = node['a']['bar']
        assert_equal(['baz'], subscripted.content)
        assert_equal(['foo', 'bar'], subscripted.path)
      end
      it 'does not follow a $ref when subscripting ' do
        subscripted = node['a']['description']
        assert_equal('hi', subscripted)
      end
    end
  end
end
