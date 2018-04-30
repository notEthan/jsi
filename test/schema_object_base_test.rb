require_relative 'test_helper'

describe Scorpio::SchemaObjectBase do
  let(:document) { {} }
  let(:path) { [] }
  let(:object) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) { {} }
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:subject) { Scorpio.class_for_schema(schema).new(object) }
  describe 'initialization' do
    describe 'nil' do
      let(:object) { nil }
      it 'initializes with nil object' do
        assert_equal(Scorpio::JSON::Node.new_by_type(nil, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary object' do
      let(:object) { Object.new }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type(object, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:object) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type({'foo' => 'bar'}, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'Scorpio::JSON::Hashnode' do
      let(:document) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::HashNode.new({'foo' => 'bar'}, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'array' do
      let(:object) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type(['foo'], []), subject.object)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'Scorpio::JSON::Arraynode' do
      let(:document) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::ArrayNode.new(['foo'], []), subject.object)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
  end
  describe '#modified_copy' do
    describe 'with an object that does have #modified_copy' do
      it 'yields the object to modify' do
        modified = subject.modified_copy do |o|
          assert_equal({}, o)
          {'a' => 'b'}
        end
        assert_equal({'a' => 'b'}, modified.object.content)
        assert_equal({}, subject.object.content)
        refute_equal(object, modified)
      end
    end
    describe 'resulting in a different type' do
      let(:schema_content) { {'type' => 'object'} }
      it 'works' do
        # I'm not really sure the best thing to do here, but this is how it is for now. this is subject to change.
        modified = subject.modified_copy do |o|
          o.to_s
        end
        assert_equal('{}', modified.object.content)
        assert_equal({}, subject.object.content)
        refute_equal(object, modified)
        # interesting side effect
        assert(subject.respond_to?(:to_hash))
        assert(!modified.respond_to?(:to_hash))
        assert_equal(Scorpio::JSON::HashNode, subject.object.class)
        assert_equal(Scorpio::JSON::Node, modified.object.class)
      end
    end
  end
  it('#fragment') { assert_equal('#', subject.fragment) }
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema({}).new(Scorpio::JSON::Node.new_by_type({'a' => 'b'}, [])).as_json)
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema({'type' => 'object'}).new(Scorpio::JSON::Node.new_by_type({'a' => 'b'}, [])).as_json)
      assert_equal(['a', 'b'], Scorpio.class_for_schema({'type' => 'array'}).new(Scorpio::JSON::Node.new_by_type(['a', 'b'], [])).as_json)
    end
  end
end
