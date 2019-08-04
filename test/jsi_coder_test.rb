require_relative 'test_helper'

describe JSI::JSICoder do
  let(:schema_instance_class) { JSI.class_for_schema(properties: {foo: {}, bar: {}}) }
  let(:options) { {} }
  let(:schema_instance_json_coder) { JSI::JSICoder.new(schema_instance_class, options) }
  describe 'json' do
    describe 'load' do
      it 'loads nil' do
        assert_nil(schema_instance_json_coder.load(nil))
      end
      it 'loads a hash' do
        assert_equal(schema_instance_class.new('foo' => 'bar'), schema_instance_json_coder.load({"foo" => "bar"}))
      end
      it 'loads something else' do
        assert_equal(schema_instance_class.new([[]]), schema_instance_json_coder.load([[]]))
      end
      describe 'array' do
        let(:options) { {array: true} }
        it 'loads an array of hashes' do
          data = [{"foo" => "bar"}, {"foo" => "baz"}]
          assert_equal([schema_instance_class.new('foo' => 'bar'), schema_instance_class.new('foo' => 'baz')], schema_instance_json_coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal([], schema_instance_json_coder.load([]))
        end
        it 'loads a not an array' do
          assert_raises(TypeError) do
            schema_instance_json_coder.load(Object.new)
          end
        end
      end
    end
    describe 'dump' do
      it 'dumps nil' do
        assert_nil(schema_instance_json_coder.dump(nil))
      end
      it 'dumps a schema_instance_class' do
        assert_equal({"foo" => "x", "bar" => "y"}, schema_instance_json_coder.dump(schema_instance_class.new(foo: 'x', bar: 'y')))
      end
      it 'dumps something else' do
        assert_raises(TypeError) do
          schema_instance_json_coder.dump(Object.new)
        end
      end
      it 'dumps some of the keys of a schema_instance_class after loading in a partial one' do
        schema_instance_class = schema_instance_json_coder.load({'foo' => 'who'})
        assert_equal({'foo' => 'who'}, schema_instance_json_coder.dump(schema_instance_class))
        schema_instance_class.bar = 'whar'
        assert_equal({'foo' => 'who', 'bar' => 'whar'}, schema_instance_json_coder.dump(schema_instance_class))
      end
      describe 'array' do
        let(:options) { {array: true} }
        it 'dumps an array of schema_instances' do
          schema_instances = [schema_instance_class.new(foo: 'x', bar: 'y'), schema_instance_class.new(foo: 'z', bar: 'q')]
          assert_equal([{"foo" => "x", "bar" => "y"}, {"foo" => "z", "bar" => "q"}], schema_instance_json_coder.dump(schema_instances))
        end
      end
    end
  end
  describe 'string' do
    let(:options) { {string: true} }
    describe 'load' do
      it 'loads nil' do
        assert_nil(schema_instance_json_coder.load(nil))
      end
      it 'loads a hash' do
        assert_equal(schema_instance_class.new('foo' => 'bar'), schema_instance_json_coder.load('{"foo": "bar"}'))
      end
      it 'loads something else' do
        assert_equal(schema_instance_class.new([[]]), schema_instance_json_coder.load('[[]]'))
      end
      it 'loads something that is not a json string' do
        assert_raises(::JSON::ParserError) do
          schema_instance_json_coder.load('??')
        end
      end
      describe 'array' do
        let(:options) { {string: true, array: true} }
        it 'loads an array of hashes' do
          data = '[{"foo": "bar"}, {"foo": "baz"}]'
          assert_equal([schema_instance_class.new('foo' => 'bar'), schema_instance_class.new('foo' => 'baz')], schema_instance_json_coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal([], schema_instance_json_coder.load('[]'))
        end
        it 'loads a not an array' do
          assert_raises(TypeError) do
            schema_instance_json_coder.load('{}')
          end
        end
      end
    end
    describe 'dump' do
      it 'dumps nil' do
        assert_nil(schema_instance_json_coder.dump(nil))
      end
      it 'dumps a schema_instance_class' do
        assert_equal('{"foo":"x","bar":"y"}', schema_instance_json_coder.dump(schema_instance_class.new(foo: 'x', bar: 'y')))
      end
      it 'dumps something else' do
        assert_raises(TypeError) do
          schema_instance_json_coder.dump(Object.new)
        end
      end
      it 'dumps some of the keys of a schema_instance_class after loading in a partial one' do
        schema_instance_class = schema_instance_json_coder.load('{"foo": "who"}')
        assert_equal("{\"foo\":\"who\"}", schema_instance_json_coder.dump(schema_instance_class))
        schema_instance_class.bar = 'whar'
        assert_equal("{\"foo\":\"who\",\"bar\":\"whar\"}", schema_instance_json_coder.dump(schema_instance_class))
      end
      describe 'array' do
        let(:options) { {string: true, array: true} }
        it 'dumps an array of schema_instances' do
          schema_instances = [schema_instance_class.new(foo: 'x', bar: 'y'), schema_instance_class.new(foo: 'z', bar: 'q')]
          assert_equal('[{"foo":"x","bar":"y"},{"foo":"z","bar":"q"}]', schema_instance_json_coder.dump(schema_instances))
        end
      end
    end
  end
end
