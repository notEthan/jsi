# frozen_string_literal: true

require_relative 'test_helper'

describe 'JSI::SchemaSet' do
  let(:schema_a) { JSI::JSONSchemaOrgDraft06.new_schema({'title' => 'A'}) }
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
  describe '#inspect' do
    it 'inspects' do
      inspect = JSI::SchemaSet[schema_a].inspect
      assert_equal(%q(JSI::SchemaSet[#{<JSI (JSI::JSONSchemaOrgDraft06) Schema> "title" => "A"}]), inspect)
    end
  end
  describe '#pretty_print' do
    it 'pretty prints' do
      pp = JSI::SchemaSet[schema_a].pretty_inspect
      assert_equal(%q(JSI::SchemaSet[#{<JSI (JSI::JSONSchemaOrgDraft06) Schema> "title" => "A"}]), pp.chomp)
    end
  end
end
