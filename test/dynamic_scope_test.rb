require_relative('test_helper')

describe("dynamic scope") do
  # in these tests I use unicode «» in variable names to indicate scope - not to be confused with any syntax/operator
  describe("multiple anchors") do
    it("applicates") do
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:x",
        "allOf": [
          {"$dynamicRef": "#a"},
          {"$dynamicRef": "#b"},
        ],
        "$defs": {
          "a": {"$dynamicAnchor": "a", "title": "x / a"},
          "b": {"$dynamicAnchor": "b", "title": "x / b"},
        },
      })
      y = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "y",
        "$dynamicAnchor": "a",
        "$defs": {
          "xref": {"$ref": "tag:x"},
        },
      })
      z = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "z",
        "$dynamicAnchor": "b",
        "$defs": {
          "xref": {"$ref": "tag:x"},
        },
      })
      x«y» = x.with_dynamic_scope_from(y) # scope: anchor a => resource y
      x«z» = x.with_dynamic_scope_from(z) # scope: anchor b => resource z
      refute_equal(x, x«y»)
      refute_equal(x, x«z»)
      assert_same(x«y», x«z».with_dynamic_scope_from(y)) # scope: anchor a => resource y (scope with b from x«z» discarded)
      assert_same(x«z», x«y».with_dynamic_scope_from(z)) # scope: anchor b => resource z (scope with a from x«y» discarded)
      assert_schemas([
        x,
        x.allOf[0],
        x.defs['a'],
        x.allOf[1],
        x.defs['b'],
      ], x.new_jsi({}))
      assert_schemas([
        y['$defs']['xref'],
        x«y»,
        x«y».allOf[0],
        y.with_dynamic_scope_from(x«y»), # scope: anchor b => x.defs['b']; anchor a => none (without_node y)
        x«y».allOf[1],
        x«y».defs['b'],
      ], y['$defs']['xref'].new_jsi({}))
      assert_schemas([
        z['$defs']['xref'],
        x«z»,
        x«z».allOf[0],
        x«z».defs['a'],
        x«z».allOf[1],
        z.with_dynamic_scope_from(x«z»), # scope: anchor a => x.defs['a']; anchor b => none (without_node z)
      ], z['$defs']['xref'].new_jsi({}))
    end
  end

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
