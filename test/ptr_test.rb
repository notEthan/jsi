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
    describe 'new with invalid tokens' do
      it 'raises' do
        err = assert_raises(TypeError) { JSI::Ptr.new({}) }
        assert_equal("tokens must be an array. got: {}", err.message)
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
  describe 'errors' do
    describe 'evaluate' do
      it 'fails to evaluate' do
        err = assert_raises(JSI::Ptr::ResolutionError) { JSI::Ptr['-'].evaluate([]) }
        assert_match(/nonexistent element/, err.message)

        ['foo', '0foo' 'foo0', '00', 1, -1, '1', '-1'].each do |token|
          err = assert_raises(JSI::Ptr::ResolutionError) { JSI::Ptr[token].evaluate([]) }
          assert_match(/is not a valid array index of \[\]/, err.message)
        end

        err = assert_raises(JSI::Ptr::ResolutionError) { JSI::Ptr['a'].evaluate({}) }
        assert_match(/not a valid key/, err.message)

        err = assert_raises(JSI::Ptr::ResolutionError) { JSI::Ptr['a'].evaluate(Object.new) }
        assert_match(/cannot be resolved/, err.message)
      end
    end
    describe 'relative pointers' do
      it 'fails' do
        err = assert_raises(JSI::Ptr::Error) { JSI::Ptr[].parent }
        assert_match(/cannot access parent of root pointer/, err.message)

        err = assert_raises(JSI::Ptr::Error) { JSI::Ptr['a', 'b'].relative_to(JSI::Ptr['c']) }
        assert_match(/is not ancestor/, err.message)
      end
    end
  end
end
