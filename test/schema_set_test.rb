# frozen_string_literal: true

require_relative 'test_helper'

describe 'JSI::SchemaSet' do
  let(:schema_a) { JSI::JSONSchemaDraft06.new_schema({'title' => 'A'}) }
  describe 'initialization' do
    describe '.new' do
      it 'initializes' do
        schema_set = JSI::SchemaSet.new([schema_a])
        assert_equal(1, schema_set.size)
      end
      it 'errors given non-schemas' do
        err = assert_raises(JSI::Schema::NotASchemaError) { JSI::SchemaSet.new([3]) }
        assert_equal("JSI::SchemaSet initialized with non-schema objects:\n3", err.message)
      end

      it 'errors given just the schema' do
        err = assert_raises(ArgumentError) { JSI::SchemaSet.new(schema_a) }
        assert_equal([
          "JSI::SchemaSet initialized with a JSI::Schema",
          "you probably meant to pass that to JSI::SchemaSet[]",
          "or to wrap that schema in a Set or Array for JSI::SchemaSet.new",
          "given: \#{<JSI (JSI::JSONSchemaDraft06) Schema> \"title\" => \"A\"}",
        ].join("\n"), err.message)
      end

      it 'errors given non-Enumerable' do
        assert_raises(ArgumentError) { JSI::SchemaSet.new(nil) }
        assert_raises(ArgumentError) { JSI::SchemaSet.new(Object.new) }
      end
    end
    describe '.build' do
      it 'initializes' do
        schema_set = JSI::SchemaSet.build do |schemas|
          schemas << schema_a
        end
        assert_equal(1, schema_set.size)
      end
      it 'errors given non-schemas' do
        err = assert_raises(JSI::Schema::NotASchemaError) do
          JSI::SchemaSet.build do |schemas|
            schemas << 3
          end
        end
        assert_equal("JSI::SchemaSet initialized with non-schema objects:\n3", err.message)
      end
    end
  end

  describe '#new_jsi' do
    it 'instantiates' do
      schema_b = JSI::JSONSchemaDraft06.new_schema({'$ref' => '#/definitions/b', 'definitions' => {'b' => {'title' => 'B'}}})
      schema_c = JSI::JSONSchemaDraft06.new_schema({'allOf' => [{'title' => 'C'}]})
      schema_set = JSI::SchemaSet[
        schema_a,
        schema_b,
        schema_c,
      ]
      assert_schemas([schema_a, schema_b.definitions['b'], schema_c, schema_c.allOf[0]], schema_set.new_jsi({}))
    end
  end
  describe '#inspect, #to_s' do
    it 'inspects' do
      set = JSI::SchemaSet[schema_a]
      assert_equal(%q(JSI::SchemaSet[#{<JSI (JSI::JSONSchemaDraft06) Schema> "title" => "A"}]), set.inspect)
      assert_equal(set.inspect, set.to_s)
    end
  end
  describe '#pretty_print' do
    it 'pretty prints' do
      pp = JSI::SchemaSet[schema_a].pretty_inspect
      assert_equal(%q(JSI::SchemaSet[#{<JSI (JSI::JSONSchemaDraft06) Schema> "title" => "A"}]), pp.chomp)
    end
  end
end

$test_report_file_loaded[__FILE__]
