require_relative 'test_helper'

describe("Base after_initialize") do
  describe("instantiating then iterating") do
    it("invokes callback on initialization") do
      ptrs = Set[]
      metaschema = JSI.new_metaschema_node(BasicMetaSchema.schema_content,
        dialect: BASIC_DIALECT,
        after_initialize: proc do |node|
          ptrs << node.jsi_ptr
        end,
      )
      assert_equal(Set[JSI::Ptr[]], ptrs)
      metaschema.jsi_each_descendent_node { }
      assert_equal(metaschema.jsi_each_descendent_node.map(&:jsi_ptr).to_set, ptrs)

      ptrs = Set[]
      schema = metaschema.new_schema({'additionalProperties' => {}},
        register: false, # avoid instantiating descendents
        after_initialize: proc do |node|
          ptrs << node.jsi_ptr
        end,
      )
      assert_equal(Set[JSI::Ptr[]], ptrs)
      schema.jsi_each_descendent_node { }
      assert_equal(Set[JSI::Ptr[], JSI::Ptr['additionalProperties']], ptrs)

      ptrs = Set[]
      jsi = schema.new_jsi({'foo' => {}},
        after_initialize: proc do |node|
          ptrs << node.jsi_ptr
        end,
      )
      assert_equal(Set[JSI::Ptr[]], ptrs)
      jsi.jsi_each_descendent_node { }
      assert_equal(Set[JSI::Ptr[], JSI::Ptr['foo']], ptrs)
    end
  end
end

$test_report_file_loaded[__FILE__]
