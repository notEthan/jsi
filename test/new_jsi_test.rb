require_relative 'test_helper'

describe 'new_jsi, new_schema' do
  describe 'new_schema' do
    it 'initializes with a block' do
      schema1 = JSI.new_schema({'$id' => 'tag:gxif'}, default_metaschema: JSI::JSONSchemaOrgDraft07) do
        define_method(:foo) { :foo }
      end
      schema2 = JSI::JSONSchemaOrgDraft07.new_schema({'$id' => 'tag:ijpa'}) do
        define_method(:foo) { :foo }
      end
      assert_equal(:foo, schema1.new_jsi([]).foo)
      assert_equal(:foo, schema2.new_jsi([]).foo)
    end
  end
end
