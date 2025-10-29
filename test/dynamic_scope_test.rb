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

  describe("several paths through three schema documents") do
    it("passes dynamic scope through application") do
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "x",
        "$defs": {
          "x1": {
            "$id": "tag:x1",
            "allOf": [
              {"title": "x allOf a", "$dynamicRef": "#a"},
              {"title": "x allOf b", "$dynamicRef": "#b"},
            ],
            "$defs": {
              "x2": {"title": "x2", "$dynamicAnchor": "a"},
              "x3": {"title": "x3", "$dynamicAnchor": "b"},
            },
          },
        },
      })
      y = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:y",
        "$defs": {
          "y1": {"title": "y1", "$dynamicAnchor": "a"},
          "y2": {"title": "y2", "$ref": "tag:x1"},
          "y3": {"title": "y3", "$ref": "tag:z"},
        },
      })
      z = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:z",
        "$ref": "tag:y#/$defs/y2",
        "$defs": {
          "z1": {"title": "z1", "$dynamicAnchor": "b"},
        },
      })

      x1 = x.defs['x1']
      y1 = y.defs['y1']
      y2 = y.defs['y2']
      y3 = y.defs['y3']
      z1 = z.defs['z1']
      x1«y2» = x1.with_dynamic_scope_from(y2)
      y2«z» = y2.with_dynamic_scope_from(z)
      x1«y2«z»» = x1.with_dynamic_scope_from(y2«z»)
      z1«y» = z1.with_dynamic_scope_from(y)

      # x1«y2» is a new root
      assert_same(x1«y2», x1«y2».jsi_root_node)

      # application
      assert_schemas([
        x1,
        x1.allOf[0],
        x1.defs['x2'],
        x1.allOf[1],
        x1.defs['x3'],
      ], x1.new_jsi({}))
      assert_schemas([y2,
        x1«y2»,
        x1«y2».allOf[0],
        y1.with_dynamic_scope_from(x1«y2»),
        x1«y2».allOf[1],
        x1«y2».defs['x3'],
      ], y2.new_jsi({}))
      assert_schemas([
        y3,
        z.with_dynamic_scope_from(y),
        y2«z»,
        x1«y2«z»»,
        x1«y2«z»».allOf[0],
        y1.with_dynamic_scope_from(z),
        x1«y2«z»».allOf[1],
        z1«y»,
      ], y3.new_jsi({}))
      assert_schemas([
        z,
        y2«z»,
        x1«y2«z»»,
        x1«y2«z»».allOf[0],
        y1.with_dynamic_scope_from(z),
        x1«y2«z»».allOf[1],
        z1«y»,
      ], z.new_jsi({}))
    end
  end

  describe("resource root below document root with dynamic scope") do
    it("applicates, consistent root nodes") do
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "x",
        "$defs": {
          "x1": {
            "$id": "tag:x1",
            "$dynamicRef": "#a",
            "$defs": {
              "x2": {"title": "x2", "$dynamicAnchor": "a"},
            },
          },
        },
      })
      y = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:y",
        "$defs": {
          "y1": {"title": "y1", "$dynamicAnchor": "a"},
          "y2": {"title": "y2", "$ref": "tag:x1"},
        },
      })
      z = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "z",
        "$ref": "tag:y#/$defs/y2",
      })

      x1 = x['$defs']['x1']
      x2 = x1['$defs']['x2']
      y1 = y['$defs']['y1']
      y2 = y['$defs']['y2']
      x1«y2» = x1.with_dynamic_scope_from(y2)
      # x1«y2» is a new root
      assert_same(x1«y2», x1«y2».jsi_root_node)

      # application
      assert_schemas([y2, x1«y2», y1], y2.new_jsi({}))
      assert_schemas([z, y2, x1«y2», y1], z.new_jsi({}))

      # then make a registry
      registry = JSI::DEFAULT_REGISTRY.dup
      # register a resource that is not its original root node
      registry.register(x1«y2»)
      # a $ref to x1 in that registry
      w = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "w",
        "$ref": "tag:x1",
      }, registry: registry)
      # when resolving x1 from w's $ref,
      # the dynamic scope from w overriding y2's scope that x1 in the registry has,
      # and that scope (empty from w) being the same as x1's original scope,
      # results in the original x1 resolved and applicated
      assert_schemas([w, x1, x2], w.new_jsi({}))
      # x1«y2» with scope from w has the original `x` root node
      assert_same(x, x1«y2».with_dynamic_scope_from(w).jsi_root_node)
    end
  end

  describe("going from a parent (x) to a child (y) via an external schema (z) with a dynamic scope that includes y will exclude y from y's dynamic scope") do
    it("passes correct scope through application") do
      # evaluates
      # indicated: r «»
      # $ref:      y «» → «a: y»                  # add dynamic anchor «a» to scope
      # child:     y/additionalProperties «a: y»  # child application (inplace would be circular)
      # $ref:      x «a: y»                       # get to the parent (x) with child y in «a: y»
      # child:     y «» → «a: y»                  # descending x to y removes y from y's dynamic scope
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:n5/x",
        "additionalProperties": {
          "$ref": "#/$defs/y",
        },
        "$defs": {
          "y": {
            "$id": "tag:n5/y",
            "$dynamicAnchor": "a",
            "$ref": "tag:n5/z",
          },
        },
      })
      y = x['$defs']['y']
      z = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:n5/z",
        "additionalProperties": {
          "$ref": "tag:n5/x",
        },
      })
      r = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$ref": "tag:n5/y",
      })

      i = r.new_jsi({'a' => {'a' => {}}})

      z«y» = z.with_dynamic_scope_from(y)
      x«y» = x.with_dynamic_scope_from(y)
      assert_schemas([r, y, z«y»], i)
      assert_schemas([z«y».additionalProperties, x«y»], i['a'])
      # note: arguably a bug; TODO address this when possible.
      # it _should_ be the case that y is the same schema as x«y»['$defs']['y'].
      # they are equal (#==) but not identical (#equal?), and it would be better if there was one instance.
      # they are different instances because they have different parents - one from x with empty dynamic scope,
      # the other from x with y in its dynamic scope, but removed descending to /$defs/y.
      refute_same(y, x«y»['$defs']['y'])
      assert_schemas([x«y».additionalProperties, x«y»['$defs']['y'], z«y»], i['a']['a'])
    end
  end

  describe("going from a parent (x) to a child (y) with a dynamic scope that includes y will exclude y from y's dynamic scope") do
    describe("y to x") do
      let(:x) do
        JSI.new_schema({
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$id": "tag:n5/x",
          "additionalProperties": {
            "$ref": "#/$defs/y",
          },
          "$defs": {
            "y": {
              "$id": "tag:n5/y",
              "$dynamicAnchor": "a",
              "additionalProperties": {
                "$ref": "tag:n5/x",
              },
            },
          },
        })
      end

      it("passes correct scope through application") do
        y = x['$defs']['y']
        r = JSI.new_schema({
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$ref": "tag:n5/y",
        })
        i = r.new_jsi({'a' => {'a' => {}}})

        x«y» = x.with_dynamic_scope_from(y)
        assert_schemas([r, y], i)
        assert_schemas([y.additionalProperties, x«y»], i['a'])
        assert_schemas([x«y».additionalProperties, x«y»['$defs']['y']], i['a']['a'])
      end

      it("applicates, with dynamic scope (b) from initial ref") do
        y = x['$defs']['y']
        r = JSI.new_schema({
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$ref": "tag:n5/y",
          "$dynamicAnchor": "b",
        })
        i = r.new_jsi({'a' => {'a' => {}}})

        y«r» = y.with_dynamic_scope_from(r)
        x«y«r»» = x.with_dynamic_scope_from(y«r»)
        assert_schemas([r, y«r»], i)
        assert_schemas([y«r».additionalProperties, x«y«r»»], i['a'])
        assert_schemas([x«y«r»».additionalProperties, x«y«r»»['$defs']['y']], i['a']['a'])
      end
    end
  end

  describe("cyclical application") do
    it("errors") do
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$dynamicAnchor": "a",
        "$ref": "tag:ap9/y",
        "title": "x",
      })
      JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:ap9/y",
        "$defs": {
          "a": {"$dynamicAnchor": "a", "title": "y / a"},
        },
        "$dynamicRef": "#a",
      })
      assert_raises(JSI::Error::ResolutionError) { x.new_jsi({}) }
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
