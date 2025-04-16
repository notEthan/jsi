require_relative 'test_helper'

describe JSI::Util do
  describe '.stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      assert_equal({'a' => 'b', 'c' => 'd', nil => 3}, JSI::Util.stringify_symbol_keys({a: 'b', 'c' => 'd', nil => 3}))
    end
    it 'stringifies JSI hash keys' do
      schema = JSI::JSONSchemaDraft07.new_schema({type: 'object'})
      actual = JSI::Util.stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => 'd', nil => 3}))
      expected = schema.new_jsi({'a' => 'b', 'c' => 'd', nil => 3})
      assert_equal(expected, actual)
    end
    describe 'non-hash-like argument' do
      it 'errors' do
        err = assert_raises(ArgumentError) { JSI::Util.stringify_symbol_keys(nil) }
        assert_equal("expected argument to be a hash; got NilClass: nil", err.message)
        err = assert_raises(ArgumentError) { JSI::Util.stringify_symbol_keys(JSI::JSONSchemaDraft07.new_schema({}).new_jsi(3)) }
        assert_equal("expected argument to be a hash; got (JSI Schema Class: #): #<JSI*1 3>", err.message)
      end
    end
  end
  describe '.deep_stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      actual = JSI::Util.deep_stringify_symbol_keys({
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
      actual = JSI::Util.deep_stringify_symbol_keys({a: 'b', 'c' => {d: 0}, nil => 3})
      expected = {'a' => 'b', 'c' => {'d' => 0}, nil => 3}
      assert_equal(expected, actual)
    end
    it 'deep stringifies JSI instance' do
      schema = JSI::JSONSchemaDraft07.new_schema({type: 'object'})
      actual = JSI::Util.deep_stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => {d: 0}, nil => 3}))
      expected = schema.new_jsi({'a' => 'b', 'c' => {'d' => 0}, nil => 3})
      assert_equal(expected, actual)
    end
  end

  describe 'deep_to_frozen' do
    it 'returns a frozen copy of a nested structure' do
      o = {'a' => ['b'], ['c', 0] => {}}
      o.default = [{}]
      of = JSI::Util.deep_to_frozen(o)
      refute_frozen(o)
      refute_frozen(o['a'])
      refute_frozen(o.keys.last)
      refute_frozen(o[['c']])
      refute_frozen(o.default)
      assert_frozen(of)
      assert_frozen(of['a'])
      assert_frozen(of['a'][0])
      assert_frozen(of.keys.last)
      assert_frozen(of.keys.last[0])
      assert_frozen(of.keys.last[1])
      assert_frozen(of[['c']])
      assert_frozen(of.default)
      assert_frozen(of.default[0])
    end

    it 'returns an already-frozen structure' do
      o = {'a'.freeze => ['b'.freeze].freeze, ['c'.freeze].freeze => {}.freeze}.freeze
      of = JSI::Util.deep_to_frozen(o)
      assert_equal(o.__id__, of.__id__)
    end

    it 'uses already-frozen parts of a structure' do
      o = {'a' => ['b'.freeze].freeze, ['c', 0] => {}}
      o.default = [{}.freeze]
      of = JSI::Util.deep_to_frozen(o)
      refute_frozen(o)
      assert_equal(o['a'].__id__, of['a'].__id__)
      refute_frozen(o.keys.last)
      refute_frozen(o[['c']])
      refute_frozen(o.default)
      assert_frozen(of)
      assert_frozen(of.keys.last)
      assert_frozen(of.keys.last[0])
      assert_frozen(of[['c']])
      assert_frozen(of.default)
      assert_equal(o.default[0].__id__, of.default[0].__id__)
    end

    it 'errors' do
      e = assert_raises(NotImplementedError) { JSI::Util.deep_to_frozen(Object.new) }
      assert_match(/\Adeep_to_frozen not implemented for class: Object\nobject: #<Object:0x\w+>\z/, e.message)

      assert_equal(0, JSI::Util.deep_to_frozen(Object.new, not_implemented: proc { 0 }))

      e = assert_raises(ArgumentError) { JSI::Util.deep_to_frozen(Hash.new { 0 }) }
      assert_equal('cannot make immutable copy of a Hash with default_proc', e.message)
    end
  end
end

$test_report_file_loaded[__FILE__]
