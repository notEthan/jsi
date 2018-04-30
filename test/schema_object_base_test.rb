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
        assert_equal(nil, subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary object' do
      let(:object) { Object.new }
      it 'initializes' do
        assert_equal(object, subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:object) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal({'foo' => 'bar'}, subject.object)
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
        assert_equal(['foo'], subject.object)
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
    describe 'SchemaObjectBase invalid' do
      let(:object) { Scorpio.class_for_schema(schema).new({}) }
      it 'initializes' do
        err = assert_raises(TypeError) { subject }
        assert_match(%r(\Aassigning another SchemaObjectBase instance to Scorpio::SchemaClasses\[\".*#\"\] object is incorrect. received: #<Scorpio::SchemaClasses\[.*\] {}>\z)m, err.message)
      end
    end
    describe 'Schema invalid' do
      let(:object) { Scorpio::Schema.new({}) }
      it 'initializes' do
        err = assert_raises(TypeError) { subject }
        assert_match(%r(\Aassigning a schema to Scorpio::SchemaClasses\[\".*#\"\] object is incorrect. received: #<Scorpio::Schema schema_id=.*>\z)m, err.message)
      end
    end
  end
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({}, [])).new({'a' => 'b'}).as_json)
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({'type' => 'object'}, [])).new({'a' => 'b'}).as_json)
      assert_equal(['a', 'b'], Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type({'type' => 'array'}, [])).new(['a', 'b']).as_json)
    end
  end
end
