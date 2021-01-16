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
  end
end
