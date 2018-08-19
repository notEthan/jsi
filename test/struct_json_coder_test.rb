require_relative 'test_helper'

describe Scorpio::StructJSONCoder do
  let(:struct) { Struct.new(:foo, :bar) }
  let(:options) { {} }
  let(:struct_json_coder) { Scorpio::StructJSONCoder.new(struct, options) }
  describe 'json' do
    describe 'load' do
      it 'loads nil' do
        assert_nil(struct_json_coder.load(nil))
      end
      it 'loads a hash' do
        assert_equal(struct.new('bar'), struct_json_coder.load({"foo" => "bar"}))
      end
      it 'loads something else' do
        assert_raises(Scorpio::StructJSONCoder::LoadError) do
          struct_json_coder.load([[]])
        end
      end
      it 'loads unrecognized keys' do
        assert_raises(Scorpio::StructJSONCoder::LoadError) do
          struct_json_coder.load({"uhoh" => "spaghettio"})
        end
      end
      describe 'array' do
        let(:options) { {array: true} }
        it 'loads an array of hashes' do
          data = [{"foo" => "bar"}, {"foo" => "baz"}]
          assert_equal([struct.new('bar'), struct.new('baz')], struct_json_coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal([], struct_json_coder.load([]))
        end
      end
    end
    describe 'dump' do
      it 'dumps nil' do
        assert_nil(struct_json_coder.dump(nil))
      end
      it 'dumps a struct' do
        assert_equal({"foo" => "x","bar" => "y"}, struct_json_coder.dump(struct.new('x', 'y')))
      end
      it 'dumps something else' do
        assert_raises(TypeError) do
          struct_json_coder.dump(Object.new)
        end
      end
      it 'dumps all the keys of a struct after loading in a partial one' do
        struct = struct_json_coder.load({'foo' => 'who'})
        assert_equal({'foo' => 'who', 'bar' => nil}, struct_json_coder.dump(struct))
        struct.bar = 'whar'
        assert_equal({'foo' => 'who', 'bar' => 'whar'}, struct_json_coder.dump(struct))
      end
      describe 'array' do
        let(:options) { {array: true} }
        it 'dumps an array of structs' do
          structs = [struct.new('x', 'y'), struct.new('z', 'q')]
          assert_equal([{"foo" => "x","bar" => "y"},{"foo" => "z","bar" => "q"}], struct_json_coder.dump(structs))
        end
      end
    end
  end
  describe 'string' do
    let(:options) { {string: true} }
    describe 'load' do
      it 'loads nil' do
        assert_nil(struct_json_coder.load(nil))
      end
      it 'loads a hash' do
        assert_equal(struct.new('bar'), struct_json_coder.load('{"foo": "bar"}'))
      end
      it 'loads something else' do
        assert_raises(Scorpio::StructJSONCoder::LoadError) do
          struct_json_coder.load('[[]]')
        end
      end
      it 'loads something that is not a json string' do
        assert_raises(JSON::ParserError) do
          struct_json_coder.load('??')
        end
      end
      it 'loads unrecognized keys' do
        assert_raises(Scorpio::StructJSONCoder::LoadError) do
          struct_json_coder.load('{"uhoh": "spaghettio"}')
        end
      end
      describe 'array' do
        let(:options) { {string: true, array: true} }
        it 'loads an array of hashes' do
          data = '[{"foo": "bar"}, {"foo": "baz"}]'
          assert_equal([struct.new('bar'), struct.new('baz')], struct_json_coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal([], struct_json_coder.load('[]'))
        end
        it 'loads a not an array' do
          assert_raises(TypeError) do
            struct_json_coder.load('{}')
          end
        end
      end
    end
    describe 'dump' do
      it 'dumps nil' do
        assert_nil(struct_json_coder.dump(nil))
      end
      it 'dumps a struct' do
        assert_equal('{"foo":"x","bar":"y"}', struct_json_coder.dump(struct.new('x', 'y')))
      end
      it 'dumps something else' do
        assert_raises(TypeError) do
          struct_json_coder.dump(Object.new)
        end
      end
      it 'dumps all the keys of a struct after loading in a partial one' do
        struct = struct_json_coder.load('{"foo": "who"}')
        assert_equal("{\"foo\":\"who\",\"bar\":null}", struct_json_coder.dump(struct))
        struct.bar = 'whar'
        assert_equal("{\"foo\":\"who\",\"bar\":\"whar\"}", struct_json_coder.dump(struct))
      end
      describe 'array' do
        let(:options) { {string: true, array: true} }
        it 'dumps an array of structs' do
          structs = [struct.new('x', 'y'), struct.new('z', 'q')]
          assert_equal('[{"foo":"x","bar":"y"},{"foo":"z","bar":"q"}]', struct_json_coder.dump(structs))
        end
      end
    end
  end
end
