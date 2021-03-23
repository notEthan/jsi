require_relative 'test_helper'

describe JSI::Ptr do
  # For example, given the document
  let(:document) do
    {
       "foo" => ["bar", "baz"],
       "" => 0,
       "a/b" => 1,
       "c%d" => 2,
       "e^f" => 3,
       "g|h" => 4,
       "i\\j" => 5,
       "k\"l" => 6,
       " " => 7,
       "m~n" => 8,
    }
  end

  describe 'initialize from pointer' do
    it 'parses' do
      # The following strings evaluate to the accompanying values:
      evaluations = [
        ""      ,     document,
        "/foo"  ,     ["bar", "baz"],
        "/foo/0",     "bar",
        "/"     ,     0,
        "/a~1b" ,     1,
        "/c%d"  ,     2,
        "/e^f"  ,     3,
        "/g|h"  ,     4,
        "/i\\j" ,     5,
        "/k\"l" ,     6,
        "/ "    ,     7,
        "/m~0n" ,     8,
      ]
      evaluations.each_slice(2) do |pointer, value|
        assert_equal(value, JSI::Ptr.from_pointer(pointer).evaluate(document))
      end
    end

    it 'raises for invalid syntax' do
      err = assert_raises(JSI::Ptr::PointerSyntaxError) do
        JSI::Ptr.from_pointer("this does not begin with slash").evaluate(document)
      end
      assert_equal("Invalid pointer syntax in \"this does not begin with slash\": pointer must begin with /", err.message)
    end
  end
  describe 'initialize from fragment' do
    # For example, given the document
    let(:document) do
      {
         "foo" => ["bar", "baz"],
         "" => 0,
         "a/b" => 1,
         "c%d" => 2,
         "e^f" => 3,
         "g|h" => 4,
         "i\\j" => 5,
         "k\"l" => 6,
         " " => 7,
         "m~n" => 8,
      }
    end

    it 'parses' do
      # the following URI fragment identifiers evaluate to the accompanying values:
      evaluations = [
        '#',            document,
        '#/foo',        ["bar", "baz"],
        '#/foo/0',      "bar",
        '#/',           0,
        '#/a~1b',       1,
        '#/c%25d',      2,
        '#/e%5Ef',      3,
        '#/g%7Ch',      4,
        '#/i%5Cj',      5,
        '#/k%22l',      6,
        '#/%20',        7,
        '#/m~0n',       8,
      ]
      evaluations.each_slice(2) do |uri, value|
        assert_equal(value, JSI::Ptr.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(document))
      end
    end

    it 'raises for invalid syntax' do
      err = assert_raises(JSI::Ptr::PointerSyntaxError) do
        JSI::Ptr.from_fragment("this does not begin with slash").evaluate(document)
      end
      assert_equal("Invalid pointer syntax in \"this does not begin with slash\": pointer must begin with /", err.message)
    end
  end
  describe 'initialization' do
    describe 'new with invalid reference_tokens' do
      it 'raises' do
        err = assert_raises(TypeError) { JSI::Ptr.new({}) }
        assert_equal("reference_tokens must be an array. got: {}", err.message)
      end
    end
    describe '.[]' do
      it 'initializates' do
        assert_equal(JSI::Ptr.new(['a']), JSI::Ptr['a'])
      end
    end
    describe 'ary_ptr given an ary' do
      it 'instantiates' do
        assert_equal(JSI::Ptr.new(['a']), JSI::Ptr.ary_ptr(['a']))
      end
    end
    describe 'ary_ptr given a pointer' do
      it 'returns it' do
        assert_equal(JSI::Ptr.new(['a']), JSI::Ptr.ary_ptr(JSI::Ptr['a']))
      end
    end
    describe 'ary_ptr given something invalid' do
      it 'raises' do
        assert_raises(TypeError) { JSI::Ptr.ary_ptr({'a' => 'b'}) }
      end
    end
  end
end
