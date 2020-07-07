require_relative 'test_helper'

document_types = [
  {
    make_document: -> (d) { d },
    jsi_document: {'a' => 'b', 'c' => {'d' => 'e'}},
    type_desc: 'Hash',
  },
  {
    make_document: -> (d) { SortOfHash.new(d) },
    jsi_document: SortOfHash.new({'a' => 'b', 'c' => SortOfHash.new({'d' => 'e'})}),
    type_desc: 'sort of Hash-like',
  },
]
document_types.each do |document_type|
  describe "JSI::JSON::HashNode with #{document_type[:type_desc]}" do
    # jsi_document of the node being tested
    let(:jsi_document) { document_type[:jsi_document] }
    # by default the node is the whole document
    let(:path) { [] }
    let(:jsi_ptr) { JSI::JSON::Pointer.new(path) }
    # the node being tested
    let(:node) { JSI::JSON::Node.new_by_type(jsi_document, jsi_ptr) }

    describe '#each' do
      it 'iterates, one argument' do
        out = []
        node.each do |arg|
          out << arg
        end
        assert_instance_of(JSI::JSON::HashNode, node['c'])
        assert_equal([['a', 'b'], ['c', node['c']]], out)
      end
      it 'iterates, two arguments' do
        out = []
        node.each do |k, v|
          out << [k, v]
        end
        assert_instance_of(JSI::JSON::HashNode, node['c'])
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
      let(:jsi_document) { document_type[:make_document].call({'a' => {'b' => 0}, 'c' => {'d' => 'e'}}) }
      # testing the node at 'c' here, merging a hash at a path within a document.
      let(:path) { ['c'] }
      it 'merges' do
        merged = node.merge('x' => 'y')
        # check the node_content at 'c' was merged with the remainder of the document intact (at 'a')
        assert_equal({'a' => {'b' => 0}, 'c' => {'d' => 'e', 'x' => 'y'}}, merged.jsi_document)
        # check the original node retains its original document
        assert_equal(document_type[:make_document].call({'a' => {'b' => 0}, 'c' => {'d' => 'e'}}), node.jsi_document)
        # check that unnecessary copies of unaffected parts of the document were not made
        assert_equal(node.jsi_document.to_hash['a'].object_id, merged.jsi_document['a'].object_id)
      end
    end
    describe '#as_json' do
      let(:jsi_document) { document_type[:make_document].call({'a' => 'b'}) }
      it '#as_json' do
        assert_equal({'a' => 'b'}, node.as_json)
        assert_equal({'a' => 'b'}, node.as_json(this_option: 'what?'))
      end
    end
    # these methods just delegate to Hash so not going to test excessively
    describe 'key only methods' do
      it('#each_key') { assert_equal(['a', 'c'], node.each_key.to_a) }
      it('#empty?')   { assert_equal(false, node.empty?) }
      it('#has_key?') { assert_equal(true, node.has_key?('a')) }
      it('#include?') { assert_equal(false, node.include?('q')) }
      it('#key?')    { assert_equal(true, node.key?('c')) }
      it('#keys')   { assert_equal(['a', 'c'], node.keys) }
      it('#length') { assert_equal(2, node.length) }
      it('#member?') { assert_equal(false, node.member?(0)) }
      it('#size')   { assert_equal(2, node.size) }
    end
    describe 'key + value methods' do
      it('#<')  { assert_equal(true, node < {'a' => 'b', 'c' => node['c'], 'x' => 'y'}) } if {}.respond_to?(:<)
      it('#<=')  { assert_equal(true, node <= node) } if {}.respond_to?(:<=)
      it('#>')    { assert_equal(true, node > {}) } if {}.respond_to?(:>)
      it('#>=')    { assert_equal(false, node >= {'foo' => 'bar'}) } if {}.respond_to?(:>=)
      it('#any?')   { assert_equal(false, node.any? { |k, v| v == 3 }) }
      it('#assoc')   { assert_equal(['a', 'b'], node.assoc('a')) }
      it('#dig')      { assert_equal('e', node.dig('c', 'd')) } if {}.respond_to?(:dig)
      it('#each_pair') { assert_equal([['a', 'b'], ['c', node['c']]], node.each_pair.to_a) }
      it('#each_value') { assert_equal(['b', node['c']], node.each_value.to_a) }
      it('#fetch')       { assert_equal('b', node.fetch('a')) }
      it('#fetch_values') { assert_equal(['b'], node.fetch_values('a')) } if {}.respond_to?(:fetch_values)
      it('#has_value?')  { assert_equal(true, node.has_value?('b')) }
      it('#invert')     { assert_equal({'b' => 'a', node['c'] => 'c'}, node.invert) }
      it('#key')       { assert_equal('a', node.key('b')) }
      it('#rassoc')   { assert_equal(['a', 'b'], node.rassoc('b')) }
      it('#to_h')    { assert_equal({'a' => 'b', 'c' => node['c']}, node.to_h) }
      it('#to_proc') { assert_equal('b', node.to_proc.call('a')) } if {}.respond_to?(:to_proc)
      if {}.respond_to?(:transform_values)
        it('#transform_values') { assert_equal({'a' => nil, 'c' => nil}, node.transform_values { |_| nil }) }
      end
      it('#value?')  { assert_equal(false, node.value?('0')) }
      it('#values')   { assert_equal(['b', node['c']], node.values) }
      it('#values_at') { assert_equal(['b'], node.values_at('a')) }
    end
    describe 'modified copy methods' do
      # I'm going to rely on the #merge test above to test the modified copy functionality and just do basic
      # tests of all the modified copy methods here
      it('#merge') { assert_equal(JSI::JSON::Node.new_doc(node.node_content), node.merge({})) }
      it('#reject') { assert_equal(JSI::JSON::Node.new_doc({}), node.reject { true }) }
      it('#select') { assert_equal(JSI::JSON::Node.new_doc({}), node.select { false }) }
      # Hash#compact only available as of ruby 2.5.0
      if {}.respond_to?(:compact)
        it('#compact') { assert_equal(JSI::JSON::Node.new_doc({"a" => "b", "c" => node.node_content.to_hash["c"]}), node.compact) }
      end
    end
    JSI::Hashlike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
      it("does not respond to destructive method #{destructive_method_name}") do
        assert(!node.respond_to?(destructive_method_name))
      end
    end
  end
end
