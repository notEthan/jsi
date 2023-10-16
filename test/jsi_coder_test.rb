require_relative 'test_helper'

describe JSI::JSICoder do
  let(:schema_content) do
    {properties: {foo: {}, bar: {}}}
  end
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07) }
  let(:options) { {} }
  let(:jsi_opt) { {} }
  let(:coder) { JSI::JSICoder.new(schema, jsi_opt: jsi_opt, **options) }

  describe 'json' do
    describe 'load' do
      it 'loads nil' do
        assert_nil(coder.load(nil))
      end
      it 'loads a hash' do
        assert_equal(schema.new_jsi({'foo' => 'bar'}), coder.load({"foo" => "bar"}))
      end
      it 'loads something else' do
        assert_equal(schema.new_jsi([[]]), coder.load([[]]))
      end

      describe 'jsi_opt' do
        let(:jsi_opt) { {stringify_symbol_keys: true} }
        it('loads') { assert_equal(schema.new_jsi({'foo' => 'bar'}), coder.load({:foo => "bar"})) }
      end

      describe 'array' do
        let(:options) { {array: true} }
        it 'loads an array of hashes' do
          data = [{"foo" => "bar"}, {"foo" => "baz"}]
          assert_equal([schema.new_jsi({'foo' => 'bar'}), schema.new_jsi({'foo' => 'baz'})], coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal([], coder.load([]))
        end
        it 'loads a not an array' do
          assert_raises(TypeError) do
            coder.load(Object.new)
          end
        end
      end
      describe 'array schema' do
        let(:schema_content) { {items: {properties: {foo: {}, bar: {}}}} }
        it 'loads an array of hashes' do
          data = [{"foo" => "bar"}, {"foo" => "baz"}]
          assert_equal(schema.new_jsi([{'foo' => 'bar'}, {'foo' => 'baz'}]), coder.load(data))
        end
        it 'loads an empty array' do
          assert_equal(schema.new_jsi([]), coder.load([]))
        end
        it 'loads a not an array' do
          instance = Object.new
          assert_equal(schema.new_jsi(instance), coder.load(instance))
        end
      end
    end
    describe 'dump' do
      it 'dumps nil' do
        assert_nil(coder.dump(nil))
      end
      it 'dumps a JSI' do
        assert_equal({"foo" => "x", "bar" => "y"}, coder.dump(schema.new_jsi({'foo' => 'x', 'bar' => 'y'})))
      end
      it 'dumps something else' do
        assert_raises(TypeError) do
          coder.dump(Object.new)
        end
      end
      it 'dumps some of the keys of a JSI after loading in a partial one' do
        jsi = coder.load({'foo' => 'who'})
        assert_equal({'foo' => 'who'}, coder.dump(jsi))
        jsi.bar = 'whar'
        assert_equal({'foo' => 'who', 'bar' => 'whar'}, coder.dump(jsi))
      end
      describe 'array' do
        let(:options) { {array: true} }
        it 'dumps an array of JSIs' do
          jsis = [schema.new_jsi({'foo' => 'x', 'bar' => 'y'}), schema.new_jsi({'foo' => 'z', 'bar' => 'q'})]
          assert_equal([{"foo" => "x", "bar" => "y"}, {"foo" => "z", "bar" => "q"}], coder.dump(jsis))
        end
      end
      describe 'array schema' do
        let(:schema_content) { {items: {properties: {foo: {}, bar: {}}}} }
        it 'dumps a JSI array' do
          jsis = schema.new_jsi([{'foo' => 'x', 'bar' => 'y'}, {'foo' => 'z', 'bar' => 'q'}])
          assert_equal([{"foo" => "x", "bar" => "y"}, {"foo" => "z", "bar" => "q"}], coder.dump(jsis))
        end
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
