require_relative 'test_helper'

describe JSI::JSON::Node do
  let(:path) { [] }
  let(:jsi_ptr) { JSI::JSON::Pointer.new(path) }
  let(:node) { JSI::JSON::Node.new(jsi_document, jsi_ptr) }

  describe 'initialization' do
    it 'initializes' do
      node = JSI::JSON::Node.new({'a' => 'b'}, jsi_ptr)
      assert_equal({'a' => 'b'}, node.jsi_document)
      assert_equal(JSI::JSON::Pointer.new([]), node.jsi_ptr)
    end
    it 'initializes, jsi_ptr is not jsi_ptr' do
      err = assert_raises(TypeError) { JSI::JSON::Node.new({'a' => 'b'}, []) }
      assert_equal('jsi_ptr must be a JSI::JSON::Pointer. got: [] (Array)', err.message)
    end
    it 'initializes, jsi_document is another Node' do
      err = assert_raises(TypeError) { JSI::JSON::Node.new(JSI::JSON::Node.new({'a' => 'b'}, jsi_ptr), jsi_ptr) }
      assert_equal("jsi_document of a Node should not be another JSI::JSON::Node: #<JSI::JSON::Node # {\"a\"=>\"b\"}>", err.message)
    end
  end
  describe 'initialization by .new_by_type' do
    it 'initializes HashNode' do
      node = JSI::JSON::Node.new_doc({'a' => 'b'})
      assert_instance_of(JSI::JSON::HashNode, node)
      assert_equal({'a' => 'b'}, node.jsi_document)
    end
    it 'initializes ArrayNode' do
      node = JSI::JSON::Node.new_doc(['a', 'b'])
      assert_instance_of(JSI::JSON::ArrayNode, node)
      assert_equal(['a', 'b'], node.jsi_document)
    end
    it 'initializes Node' do
      object = Object.new
      node = JSI::JSON::Node.new_doc(object)
      assert_instance_of(JSI::JSON::Node, node)
      assert_equal(object, node.jsi_document)
    end
  end
  describe '#jsi_ptr' do
    it 'is a JSI::JSON::Pointer' do
      assert_instance_of(JSI::JSON::Pointer, JSI::JSON::Node.new({}, jsi_ptr).jsi_ptr)
    end
  end
  describe '#jsi_node_content' do
    it 'returns the jsi_node_content at the root' do
      assert_equal({'a' => 'b'}, JSI::JSON::Node.new({'a' => 'b'}, jsi_ptr).jsi_node_content)
    end
    it 'returns the jsi_node_content from the deep' do
      assert_equal('b', JSI::JSON::Node.new([0, {'x' => [{'a' => ['b']}]}], JSI::JSON::Pointer.new([1, 'x', 0, 'a', 0])).jsi_node_content)
    end
  end
  describe '#deref' do
    let(:jsi_document) do
      {
        'foo' => {'bar' => ['baz']},
        'a' => {'$ref' => '#/foo'},
      }
    end
    it 'follows a $ref' do
      assert_equal({'bar' => ['baz']}, node['a'].deref.jsi_node_content)
    end
    it 'returns the node when there is no $ref to follow' do
      assert_equal({'bar' => ['baz']}, node['foo'].deref.jsi_node_content)
    end
    describe "dealing with google's invalid $refs" do
      let(:jsi_document) do
        {
          'schemas' => {'bar' => {'description' => ['baz']}},
          'a' => {'$ref' => 'bar', 'foo' => 'bar'},
        }
      end
      it 'subscripts a node consisting of a $ref WITHOUT following' do
        subscripted = node['a']
        assert_equal({'$ref' => 'bar', 'foo' => 'bar'}, subscripted.jsi_node_content)
        assert_equal(JSI::JSON::Pointer.new(['a']), subscripted.jsi_ptr)
      end
      it 'looks for a node in #/schemas with the name of the $ref' do
        assert_equal({'description' => ['baz']}, node['a'].deref.jsi_node_content)
      end
    end
    describe "dealing with whatever this is" do
      # I think google uses this style in some cases maybe. I don't remember.
      let(:jsi_document) do
        {
          'schemas' => {'bar' => {'id' => 'BarID', 'description' => 'baz'}},
          'a' => {'$ref' => 'BarID'},
        }
      end
      it 'looks for a node in #/schemas with the name of the $ref' do
        assert_equal({'id' => 'BarID', 'description' => 'baz'}, node['a'].deref.jsi_node_content)
      end
    end
  end
  describe '#[]' do
    describe 'without dereferencing' do
      let(:jsi_document) { [0, {'x' => [{'a' => ['b']}]}] }
      it 'subscripts arrays and hashes' do
        assert_equal('b', node[1]['x'][0]['a'][0])
      end
      it 'returns ArrayNode for an array' do
        subscripted = node[1]['x']
        assert_instance_of(JSI::JSON::ArrayNode, subscripted)
        assert_equal([{'a' => ['b']}], subscripted.jsi_node_content)
        assert_equal(JSI::JSON::Pointer.new([1, 'x']), subscripted.jsi_ptr)
      end
      it 'returns HashNode for a Hash' do
        subscripted = node[1]
        assert_instance_of(JSI::JSON::HashNode, subscripted)
        assert_equal({'x' => [{'a' => ['b']}]}, subscripted.jsi_node_content)
        assert_equal(JSI::JSON::Pointer.new([1]), subscripted.jsi_ptr)
      end
      describe 'jsi_node_content does not respond to []' do
        let(:jsi_document) { Object.new }
        it 'cannot subscript' do
          err = assert_raises(NoMethodError) { node['x'] }
          assert_equal("undefined method `[]`\nsubscripting with \"x\" (String) from Object. content is: #{jsi_document.pretty_inspect.chomp}", err.message)
        end
      end
    end
    describe 'with dereferencing' do
      let(:jsi_document) do
        {
          'foo' => {'bar' => ['baz']},
          'a' => {'$ref' => '#/foo', 'description' => 'hi'}, # not sure a description is actually allowed here, whatever
        }
      end
      it 'subscripts a node consisting of a $ref without following' do
        subscripted = node['a']
        assert_equal({'$ref' => '#/foo', 'description' => 'hi'}, subscripted.jsi_node_content)
        assert_equal(JSI::JSON::Pointer.new(['a']), subscripted.jsi_ptr)
      end
    end
  end
  describe '#[]=' do
    let(:jsi_document) { [0, {'x' => [{'a' => ['b']}]}] }
    it 'assigns' do
      node[0] = 'abcdefg'
      assert_equal(['abcdefg', {'x' => [{'a' => ['b']}]}], jsi_document)
      string_node = JSI::JSON::Node.new(jsi_document, JSI::JSON::Pointer.new([0]))
      string_node[0..2] = '0'
      assert_equal(['0defg', {'x' => [{'a' => ['b']}]}], jsi_document)
      node[0] = node[1]
      assert_equal([{'x' => [{'a' => ['b']}]}, {'x' => [{'a' => ['b']}]}], jsi_document)
    end
    it 'assigns, deeper' do
      node[1]['y'] = node[1]['x'][0]
      assert_equal([0, {'x' => [{'a' => ['b']}], 'y' => {'a' => ['b']}}], jsi_document)
    end
  end
  describe '#jsi_root_node' do
    let(:jsi_document) { {'a' => {'b' => 3}} }
    it 'has jsi_node_content that is the jsi_document' do
      assert_equal({'a' => {'b' => 3}}, node['a'].jsi_root_node.jsi_node_content)
    end
  end
  describe '#jsi_parent_node' do
    let(:jsi_document) { {'a' => {'b' => []}} }
    it 'finds a parent' do
      sub = node['a']['b']
      assert_equal(JSI::JSON::Pointer.new(['a', 'b']), sub.jsi_ptr)
      parent = sub.jsi_parent_node
      assert_equal(JSI::JSON::Pointer.new(['a']), parent.jsi_ptr)
      assert_equal({'b' => []}, parent.jsi_node_content)
      assert_equal(node['a'], parent)
      root_from_sub = sub.jsi_parent_node.jsi_parent_node
      assert_equal(JSI::JSON::Pointer.new([]), root_from_sub.jsi_ptr)
      assert_equal({'a' => {'b' => []}}, root_from_sub.jsi_node_content)
      assert_equal(node, root_from_sub)
      err = assert_raises(JSI::JSON::Pointer::ReferenceError) do
        root_from_sub.jsi_parent_node
      end
      assert_equal('cannot access parent of root pointer: JSI::JSON::Pointer[]', err.message)
    end
  end
  describe '#modified_copy' do
    let(:jsi_document) { [['b', 'q'], {'c' => ['d', 'e']}] }
    let(:path) { ['1', 'c'] }
    it 'returns a different object' do
      # simplest thing
      modified_dup = node.modified_copy(&:dup)
      # it is equal - being a dup
      assert_equal(node, modified_dup)
      # but different object
      refute_equal(node.object_id, modified_dup.object_id)
      # the parents, obviously, are different
      refute_equal(node.jsi_parent_node.jsi_node_content.object_id, modified_dup.jsi_parent_node.jsi_node_content.object_id)
      refute_equal(node.jsi_parent_node.jsi_parent_node.jsi_node_content.object_id, modified_dup.jsi_parent_node.jsi_parent_node.jsi_node_content.object_id)
      # but any untouched part(s) - in this case the ['b', 'q'] at jsi_document[0] - are untouched
      assert_equal(node.jsi_root_node[0].jsi_node_content.object_id, modified_dup.jsi_root_node[0].jsi_node_content.object_id)
    end
    it 'returns the same object' do
      unmodified_dup = node.modified_copy { |o| o }
      assert_equal(unmodified_dup, node)
      # same object, since the block just returned it
      refute_equal(node.object_id, unmodified_dup.object_id)
      # the parents are unchanged since the object is the same
      assert_equal(node.jsi_parent_node.jsi_node_content.object_id, unmodified_dup.jsi_parent_node.jsi_node_content.object_id)
      assert_equal(node.jsi_parent_node.jsi_parent_node.jsi_node_content.object_id, unmodified_dup.jsi_parent_node.jsi_parent_node.jsi_node_content.object_id)
      # same as the other: any untouched part(s) - in this case the ['b', 'q'] at jsi_document[0] - are untouched
      assert_equal(node.jsi_root_node[0].jsi_node_content.object_id, unmodified_dup.jsi_root_node[0].jsi_node_content.object_id)
    end
    it 'raises subscripting string from array' do
      err = assert_raises(TypeError) { JSI::JSON::Node.new(jsi_document, JSI::JSON::Pointer.new(['x'])).modified_copy(&:dup) }
      assert_match(%r(\Abad subscript "x" with remaining subpath: \[\] for array: \[.*\]\z)m, err.message)
    end
    it 'raises subscripting from invalid subpath' do
      err = assert_raises(TypeError) { JSI::JSON::Node.new(jsi_document, JSI::JSON::Pointer.new([0, 0, 'what'])).modified_copy(&:dup) }
      assert_match(%r(bad subscript: "what" with remaining subpath: \[\] for content: "b"\z)m, err.message)
    end
  end
  describe '#inspect' do
    let(:jsi_document) { {'a' => {'c' => ['d', 'e']}} }
    let(:path) { ['a'] }
    it 'inspects' do
      assert_equal(%Q(#<JSI::JSON::Node #/a {"c"=>["d", "e"]}>), node.inspect)
    end
  end
  describe '#pretty_print' do
    let(:jsi_document) { {'a' => {'c' => ['d', 'e']}} }
    let(:path) { ['a'] }
    it 'pretty prints' do
      assert_equal(%Q(#<JSI::JSON::Node #/a {"c"=>["d", "e"]}>), node.pretty_inspect.chomp)
    end
  end
  describe '#jsi_fingerprint' do
    let(:jsi_ptr) { JSI::JSON::Pointer.new([]) }
    it 'hashes consistently' do
      assert_equal('x', {JSI::JSON::Node.new([0], jsi_ptr) => 'x'}[JSI::JSON::Node.new([0], jsi_ptr)])
    end
    it 'hashes consistently regardless of the Node being decorated as a subclass' do
      assert_equal('x', {JSI::JSON::Node.new_doc([0]) => 'x'}[JSI::JSON::Node.new([0], jsi_ptr)])
      assert_equal('x', {JSI::JSON::Node.new([0], jsi_ptr) => 'x'}[JSI::JSON::Node.new_doc([0])])
    end
    it '==' do
      assert_equal(JSI::JSON::Node.new([0], jsi_ptr), JSI::JSON::Node.new([0], jsi_ptr))
      assert_equal(JSI::JSON::Node.new_doc([0]), JSI::JSON::Node.new([0], jsi_ptr))
      assert_equal(JSI::JSON::Node.new([0], jsi_ptr), JSI::JSON::Node.new_doc([0]))
      assert_equal(JSI::JSON::Node.new_doc([0]), JSI::JSON::Node.new_doc([0]))
    end
    it '!=' do
      refute_equal(JSI::JSON::Node.new([0], jsi_ptr), JSI::JSON::Node.new({}, jsi_ptr))
      refute_equal(JSI::JSON::Node.new_doc([0]), JSI::JSON::Node.new({}, jsi_ptr))
      refute_equal(JSI::JSON::Node.new([0], jsi_ptr), JSI::JSON::Node.new_doc({}))
      refute_equal(JSI::JSON::Node.new_doc([0]), JSI::JSON::Node.new_doc({}))
      refute_equal({}, JSI::JSON::Node.new_doc({}))
      refute_equal(JSI::JSON::Node.new_doc({}), {})
    end
  end
  describe '#as_json' do
    let(:jsi_document) { {'a' => 'b'} }
    it '#as_json' do
      assert_equal({'a' => 'b'}, node.as_json)
    end
  end
end
