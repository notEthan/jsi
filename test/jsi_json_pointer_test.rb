require_relative 'test_helper'

describe JSI::JSON::Pointer do
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
        assert_equal(value, JSI::JSON::Pointer.from_pointer(pointer).evaluate(document))
      end
    end

    it 'raises for invalid syntax' do
      err = assert_raises(JSI::JSON::Pointer::PointerSyntaxError) do
        JSI::JSON::Pointer.from_pointer("this does not begin with slash").evaluate(document)
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
        assert_equal(value, JSI::JSON::Pointer.from_fragment(Addressable::URI.parse(uri).fragment).evaluate(document))
      end
    end

    it 'raises for invalid syntax' do
      err = assert_raises(JSI::JSON::Pointer::PointerSyntaxError) do
        JSI::JSON::Pointer.from_fragment("this does not begin with slash").evaluate(document)
      end
      assert_equal("Invalid pointer syntax in \"this does not begin with slash\": pointer must begin with /", err.message)
    end
  end
  describe 'initialize' do
    describe 'invalid reference_tokens' do
      it 'raises' do
        err = assert_raises(TypeError) { JSI::JSON::Pointer.new({}) }
        assert_equal("reference_tokens must be an array. got: {}", err.message)
      end
    end
  end
end
