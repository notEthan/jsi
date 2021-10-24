require_relative 'test_helper'

describe JSI::Util do
  describe '.stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      assert_equal({'a' => 'b', 'c' => 'd', nil => 3}, JSI::Util.stringify_symbol_keys({a: 'b', 'c' => 'd', nil => 3}))
    end
    it 'stringifies JSI hash keys' do
      schema = JSI.new_schema({type: 'object'})
      expected = JSI::Util.stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => 'd', nil => 3}))
      actual = schema.new_jsi({'a' => 'b', 'c' => 'd', nil => 3})
      assert_equal(expected, actual)
    end
    describe 'non-hash-like argument' do
      it 'errors' do
        err = assert_raises(ArgumentError) { JSI::Util.stringify_symbol_keys(nil) }
        assert_equal("expected argument to be a hash; got NilClass: nil", err.message)
        err = assert_raises(ArgumentError) { JSI::Util.stringify_symbol_keys(JSI.new_schema({}).new_jsi(3)) }
        assert_equal("expected argument to be a hash; got (JSI Schema Class: #): #<JSI 3>", err.message)
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
      schema = JSI.new_schema({type: 'object'})
      actual = JSI::Util.deep_stringify_symbol_keys(schema.new_jsi({a: 'b', 'c' => {d: 0}, nil => 3}))
      expected = schema.new_jsi({'a' => 'b', 'c' => {'d' => 0}, nil => 3})
      assert_equal(expected, actual)
    end
  end
  describe 'ensure_module_set' do
    it 'raises' do
      err = assert_raises(TypeError) { JSI::Util.ensure_module_set([0]) }
      assert_match(/0/, err.message)
      err = assert_raises(TypeError) { JSI::Util.ensure_module_set(Set[0].freeze) }
      assert_match(/0/, err.message)
    end
  end
  describe 'AttrStruct' do
    Foo = JSI::Util::AttrStruct[*%w(bar)]
    it 'structs' do
      foo = Foo.new(bar: 'bar')
      assert_equal('bar', foo.bar)
      assert_equal('bar', foo['bar'])
      assert_equal('bar', foo[:bar])
      foo.bar = 'baar'
      assert_equal('baar', foo.bar)
      foo['bar'] = 'baaar'
      assert_equal('baaar', foo.bar)
      foo[:bar] = 'baaaar'
      assert_equal('baaaar', foo.bar)
      assert_equal(foo, Foo.new(bar: foo.bar))
      refute_equal(foo, Foo.new(bar: 'who'))
    end
    it 'errors' do
      assert_raises(ArgumentError) { JSI::Util::AttrStruct[3] }
      assert_raises(TypeError) { Foo.new(3) }
      assert_raises(JSI::Util::AttrStruct::UndefinedAttributeKey) { Foo.new(x: 'y') }
      assert_raises(JSI::Util::AttrStruct::UndefinedAttributeKey) { Foo.new[:x] = 'y' }
    end
    it 'is pretty' do
      foo = Foo.new(bar: {'foo' => 'foooooooooooooooooooooo', 'bar' => [3.14159], 'baz' => true, 'qux' => []})
      assert_equal(%q(#<Foo bar: {"foo"=>"foooooooooooooooooooooo", "bar"=>[3.14159], "baz"=>true, "qux"=>[]}>), foo.inspect)
      pp = <<~PP
        #<Foo
          bar: {"foo"=>"foooooooooooooooooooooo",
           "bar"=>[3.14159],
           "baz"=>true,
           "qux"=>[]}
        >
        PP
      assert_equal(pp, foo.pretty_inspect)
    end
  end
end
