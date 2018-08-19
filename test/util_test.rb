require_relative 'test_helper'

describe Scorpio::Util do
  describe '.stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      assert_equal({'a' => 'b', 'c' => 'd', nil => 3}, Scorpio.stringify_symbol_keys({a: 'b', 'c' => 'd', nil => 3}))
    end
    it 'stringifies HashNode keys' do
      actual = Scorpio.stringify_symbol_keys(Scorpio::JSON::HashNode.new({a: 'b', 'c' => 'd', nil => 3}, []))
      expected = Scorpio::JSON::HashNode.new({'a' => 'b', 'c' => 'd', nil => 3}, [])
      assert_equal(expected, actual)
    end
    it 'stringifies SchemaObjectBase hash keys' do
      klass = Scorpio.class_for_schema(type: 'object')
      expected = Scorpio.stringify_symbol_keys(klass.new(Scorpio::JSON::HashNode.new({a: 'b', 'c' => 'd', nil => 3}, [])))
      actual = klass.new(Scorpio::JSON::HashNode.new({'a' => 'b', 'c' => 'd', nil => 3}, []))
      assert_equal(expected, actual)
    end
    describe 'non-hash-like argument' do
      it 'errors' do
        err = assert_raises(ArgumentError) { Scorpio.stringify_symbol_keys(nil) }
        assert_equal("expected argument to be a hash; got NilClass: nil", err.message)
        err = assert_raises(ArgumentError) { Scorpio.stringify_symbol_keys(Scorpio::JSON::Node.new(3, [])) }
        assert_equal("expected argument to be a hash; got Scorpio::JSON::Node: #<Scorpio::JSON::Node fragment=\"#\" 3>", err.message)
        err = assert_raises(ArgumentError) { Scorpio.stringify_symbol_keys(Scorpio.class_for_schema({}).new(Scorpio::JSON::Node.new(3, []))) }
        assert_match(%r(\Aexpected argument to be a hash; got Scorpio::SchemaClasses\["[^"]+#"\]: #<Scorpio::SchemaClasses\["[^"]+#"\]\n  #<Scorpio::JSON::Node fragment="#" 3>\n>\z)m, err.message)
      end
    end
  end
  describe '.deep_stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      actual = Scorpio.deep_stringify_symbol_keys({
        a: 'b',
        'c' => [
          {d: true},
          [{'e' => 0}],
        ],
        nil => 3,
      })
      expected = {
        'a' => 'b',
        'c' => [
          {'d' => true},
          [{'e' => 0}],
        ],
        nil => 3,
      }
      assert_equal(expected, actual)
    end
    it 'deep stringifies HashNode keys' do
      actual = Scorpio.deep_stringify_symbol_keys(Scorpio::JSON::HashNode.new({a: 'b', 'c' => {d: 0}, nil => 3}, []))
      expected = Scorpio::JSON::HashNode.new({'a' => 'b', 'c' => {'d' => 0}, nil => 3}, [])
      assert_equal(expected, actual)
    end
    it 'deep stringifies SchemaObjectBase instance on initialize' do
      klass = Scorpio.class_for_schema(type: 'object')
      expected = klass.new(Scorpio::JSON::HashNode.new({a: 'b', 'c' => {d: 0}, nil => 3}, []))
      actual = klass.new(Scorpio::JSON::HashNode.new({'a' => 'b', 'c' => {'d' => 0}, nil => 3}, []))
      assert_equal(expected, actual)
    end
  end
end
