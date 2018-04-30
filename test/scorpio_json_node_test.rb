require_relative 'test_helper'

describe Scorpio::JSON::Node do
  let(:path) { [] }
  let(:node) { Scorpio::JSON::Node.new(document, path) }

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
  describe '#deref' do
    let(:document) do
      {
        'foo' => {'bar' => ['baz']},
        'a' => {'$ref' => '#/foo'},
      }
    end
    it 'follows a $ref' do
      assert_equal({'bar' => ['baz']}, node['a'].deref.content)
    end
    it 'returns the node when there is no $ref to follow' do
      assert_equal({'bar' => ['baz']}, node['foo'].deref.content)
    end
    describe "dealing with google's invalid $refs" do
      let(:document) do
        {
          'schemas' => {'bar' => {'description' => ['baz']}},
          'a' => {'$ref' => 'bar', 'foo' => 'bar'},
        }
      end
      it 'subscripts a node consisting of a $ref WITHOUT following' do
        subscripted = node['a']
        assert_equal({'$ref' => 'bar', 'foo' => 'bar'}, subscripted.content)
        assert_equal(['a'], subscripted.path)
      end
      it 'looks for a node in #/schemas with the name of the $ref' do
        assert_equal({'description' => ['baz']}, node['a'].deref.content)
      end
      it 'follows a $ref when subscripting past it' do
        subscripted = node['a']['description']
        assert_equal(['baz'], subscripted.content)
        assert_equal(['schemas', 'bar', 'description'], subscripted.path)
      end
      it 'does not follow a $ref when subscripting a key that is present' do
        subscripted = node['a']['foo']
        assert_equal('bar', subscripted)
      end
    end
    describe "dealing with whatever this is" do
      # I think google uses this style in some cases maybe. I don't remember.
      let(:document) do
        {
          'schemas' => {'bar' => {'id' => 'BarID', 'description' => 'baz'}},
          'a' => {'$ref' => 'BarID'},
        }
      end
      it 'looks for a node in #/schemas with the name of the $ref' do
        assert_equal({'id' => 'BarID', 'description' => 'baz'}, node['a'].deref.content)
      end
    end
  end
  describe '#[]' do
    describe 'without dereferencing' do
      let(:document) { [0, {'x' => [{'a' => ['b']}]}] }
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
      it 'does not follow a $ref when subscripting a key that is present' do
        subscripted = node['a']['description']
        assert_equal('hi', subscripted)
      end
    end
  end
  describe '#document_node' do
    let(:document) { {'a' => {'b' => 3}} }
    it 'has content that is the document' do
      assert_equal({'a' => {'b' => 3}}, node['a'].document_node.content)
    end
  end
  describe '#parent_node' do
    let(:document) { {'a' => {'b' => []}} }
    it 'finds a parent' do
      sub = node['a']['b']
      assert_equal(['a', 'b'], sub.path)
      parent = sub.parent_node
      assert_equal(['a'], parent.path)
      assert_equal({'b' => []}, parent.content)
      assert_equal(node['a'], parent)
      root_from_sub = sub.parent_node.parent_node
      assert_equal([], root_from_sub.path)
      assert_equal({'a' => {'b' => []}}, root_from_sub.content)
      assert_equal(node, root_from_sub)
      err = assert_raises(::JSON::Schema::Pointer::ReferenceError) do
        root_from_sub.parent_node
      end
      assert_match(/\Acannot access parent of root node: #\{<Scorpio::JSON::HashNode/, err.message)
    end
  end
  describe '#pointer_path' do
    let(:document) { {'a' => {'b' => 3}} }
    it 'is empty' do
      assert_equal('', node.pointer_path)
    end
    it 'is not empty' do
      assert_equal('/a', node['a'].pointer_path)
    end
    describe 'containing an empty string and some slashes and tildes that need escaping' do
      let(:document) { {'' => {'a/b~c!d#e[f]' => []}} }
      it 'matches' do
        assert_equal('//a~1b~0c!d#e[f]', node['']['a/b~c!d#e[f]'].pointer_path)
      end
    end
  end
  describe '#fragment' do
    let(:document) { {'a' => {'b' => 3}} }
    it 'is empty' do
      assert_equal('#', node.fragment)
    end
    it 'is not empty' do
      assert_equal('#/a', node['a'].fragment)
    end
    describe 'containing an empty string and some slashes and tildes that need escaping' do
      let(:document) { {'' => {'a/b~c!d#e[f]' => []}} }
      it 'matches' do
        assert_equal('#//a~1b~0c!d#e%5Bf%5D', node['']['a/b~c!d#e[f]'].fragment)
      end
    end
  end
  describe '#modified_copy' do
    let(:document) { [['b', 'q'], {'c' => ['d', 'e']}] }
    let(:path) { ['1', 'c'] }
    it 'returns a different object' do
      # simplest thing
      modified_dup = node.modified_copy(&:dup)
      # it is equal - being a dup
      assert_equal(modified_dup, node)
      # but different object
      refute_equal(node.object_id, modified_dup.object_id)
      # the parents, obviously, are different
      refute_equal(node.parent_node.content.object_id, modified_dup.parent_node.content.object_id)
      refute_equal(node.parent_node.parent_node.content.object_id, modified_dup.parent_node.parent_node.content.object_id)
      # but any untouched part(s) - in this case the ['b', 'q'] at document[0] - are untouched
      assert_equal(node.document_node[0].content.object_id, modified_dup.document_node[0].content.object_id)
    end
    it 'returns the same object' do
      unmodified_dup = node.modified_copy { |o| o }
      assert_equal(unmodified_dup, node)
      # same object, since the block just returned it
      refute_equal(node.object_id, unmodified_dup.object_id)
      # the parents are unchanged since the object is the same
      assert_equal(node.parent_node.content.object_id, unmodified_dup.parent_node.content.object_id)
      assert_equal(node.parent_node.parent_node.content.object_id, unmodified_dup.parent_node.parent_node.content.object_id)
      # same as the other: any untouched part(s) - in this case the ['b', 'q'] at document[0] - are untouched
      assert_equal(node.document_node[0].content.object_id, unmodified_dup.document_node[0].content.object_id)
    end
    it 'raises subscripting string from array' do
      err = assert_raises(TypeError) { Scorpio::JSON::Node.new(document, ['x']).modified_copy(&:dup) }
      assert_match(%r(\Abad subscript "x" with remaining subpath: \[\] for array: \[.*\]\z)m, err.message)
    end
    it 'raises subscripting from invalid subpath' do
      err = assert_raises(TypeError) { Scorpio::JSON::Node.new(document, [0, 0, 'what']).modified_copy(&:dup) }
      assert_match(%r(bad subscript: "what" with remaining subpath: \[\] for content: "b"\z)m, err.message)
    end
  end
  describe '#fingerprint' do
    it 'hashes consistently' do
      assert_equal('x', {Scorpio::JSON::Node.new([0], []) => 'x'}[Scorpio::JSON::Node.new([0], [])])
    end
    it 'hashes consistently regardless of the Node being decorated as a subclass' do
      assert_equal('x', {Scorpio::JSON::Node.new_by_type([0], []) => 'x'}[Scorpio::JSON::Node.new([0], [])])
      assert_equal('x', {Scorpio::JSON::Node.new([0], []) => 'x'}[Scorpio::JSON::Node.new_by_type([0], [])])
    end
    it '==' do
      assert_equal(Scorpio::JSON::Node.new([0], []), Scorpio::JSON::Node.new([0], []))
      assert_equal(Scorpio::JSON::Node.new_by_type([0], []), Scorpio::JSON::Node.new([0], []))
      assert_equal(Scorpio::JSON::Node.new([0], []), Scorpio::JSON::Node.new_by_type([0], []))
      assert_equal(Scorpio::JSON::Node.new_by_type([0], []), Scorpio::JSON::Node.new_by_type([0], []))
    end
    it '!=' do
      refute_equal(Scorpio::JSON::Node.new([0], []), Scorpio::JSON::Node.new({}, []))
      refute_equal(Scorpio::JSON::Node.new_by_type([0], []), Scorpio::JSON::Node.new({}, []))
      refute_equal(Scorpio::JSON::Node.new([0], []), Scorpio::JSON::Node.new_by_type({}, []))
      refute_equal(Scorpio::JSON::Node.new_by_type([0], []), Scorpio::JSON::Node.new_by_type({}, []))
      refute_equal({}, Scorpio::JSON::Node.new_by_type({}, []))
      refute_equal(Scorpio::JSON::Node.new_by_type({}, []), {})
    end
  end
  describe '#as_json' do
    let(:document) { {'a' => 'b'} }
    it '#as_json' do
      assert_equal({'a' => 'b'}, node.as_json)
    end
  end
end
