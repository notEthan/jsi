require_relative 'test_helper'

describe JSI::Util do
  describe '.stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      assert_equal({'a' => 'b', 'c' => 'd', nil => 3}, JSI.stringify_symbol_keys({a: 'b', 'c' => 'd', nil => 3}))
    end
    it 'stringifies JSI hash keys' do
      schema = JSI::Schema.new({type: 'object'})
      expected = JSI.stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => 'd', nil => 3}))
      actual = schema.new_jsi({'a' => 'b', 'c' => 'd', nil => 3})
      assert_equal(expected, actual)
    end
    describe 'non-hash-like argument' do
      it 'errors' do
        err = assert_raises(ArgumentError) { JSI.stringify_symbol_keys(nil) }
        assert_equal("expected argument to be a hash; got NilClass: nil", err.message)
        err = assert_raises(ArgumentError) { JSI.stringify_symbol_keys(JSI::Schema.new({}).new_jsi(3)) }
        assert_equal("expected argument to be a hash; got (JSI Schema Class: #): #<JSI 3>", err.message)
      end
    end
  end
  describe '.deep_stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      actual = JSI.deep_stringify_symbol_keys({
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
    it 'deep stringifies Hash keys' do
      actual = JSI.deep_stringify_symbol_keys({a: 'b', 'c' => {d: 0}, nil => 3})
      expected = {'a' => 'b', 'c' => {'d' => 0}, nil => 3}
      assert_equal(expected, actual)
    end
    it 'deep stringifies JSI instance' do
      schema = JSI::Schema.new(type: 'object')
      actual = JSI.deep_stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => {d: 0}, nil => 3}))
      expected = schema.new_jsi({'a' => 'b', 'c' => {'d' => 0}, nil => 3})
      assert_equal(expected, actual)
    end
  end
end
