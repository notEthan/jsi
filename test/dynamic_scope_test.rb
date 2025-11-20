require_relative('test_helper')

describe("dynamic scope") do
  describe("modified copy") do
    it("retains dynamic scope") do
      a = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:41d2",
        "$dynamicRef": "#x",
        "additionalProperties": {},
        "$defs": {
          "x": {"$dynamicAnchor": "x"},
        },
      })
      b = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$ref": "tag:41d2",
        "$defs": {
          "x": {"$dynamicAnchor": "x"},
        },
      })

      # no scope from b
      i = a.new_jsi({'p' => {}})
      assert_schemas([a, a['$defs']['x']], i)
      assert_schemas([a.additionalProperties], i['p'])

      # a, scoped
      b_a = a.with_dynamic_scope_from(b)

      # `b_a` is the the same schema applied from b's $ref
      assert_schemas([b, b_a, b['$defs']['x']], b.new_jsi({'p' => {}}))

      # a, scoped, modified copy
      asm = b_a.merge('additionalProperties' => {'$dynamicRef' => '#x'})

      # modified copy retains scope from b
      i2 = asm.new_jsi({'p' => {}})
      assert_schemas([asm, b['$defs']['x']], i2)
      assert_schemas([asm.additionalProperties, b['$defs']['x']], i2['p'])
    end
  end
end

$test_report_file_loaded[__FILE__]
