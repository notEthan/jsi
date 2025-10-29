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

  describe("many paths through a complex schema changing dynamic scope") do
    it("applicates dynamically scoped schemas") do
      # this big old mess of a test covers a variety of ways evaluation applies dynamic scope.
      # it has combinations of schemas:
      # - with/without $dynamicAnchor
      # - that are/are not resources (having $id)
      # - with/without dynamic scope mapping anchors that are present in the schema to another schema
      # - resolved from registry or from resource root by pointer
      #
      # the large number of expectations encoded in `exps` were initially programmatically
      # generated, then cleaned up and reviewed for correctness (to some degree).
      # this could probably be cut down some, there is certainly some amount of redundancy
      # in the included `exps` entries, the same combination of circumstances tested several
      # times without significant variation.
      #
      # the approach to generation is roughly:
      # - from a starting indicated schema (`ind`), that being either `x` or a reference to
      #   a schema within `x`, with or without existing dynamic anchors (see `mkrefschema`)
      # - construct an instance with properties described by the current schema,
      #   recursing each property's subschema to a set depth
      #
      #   def build(i, depth)
      #     i.jsi_schemas.each do |s|
      #       (s.properties || {}).each_key do |pn|
      #         i = i.merge(pn => {})
      #         i = i.merge(pn => build(i[pn], depth - 1).jsi_node_content) if depth > 0
      #       end
      #     end
      #     i
      #   end
      #   (i = build(x.new_jsi({}), 3)); nil # avoid inspecting this in irb, it is much too large
      # - name the schemas' modules that describe each node so jsi_schema_module_name_from_ancestor can identify them
      #   X = x.jsi_schema_module; X«rxa» = x«rxa».jsi_schema_module; etc
      #   this is slightly a pain of copy/pasting assignments from this test and uppercasing the first letter.
      # - for each unique combination of schemas describing nodes in the instance,
      #   construct an `exps` entry for one representative of the described nodes
      #
      #   def exps(indname, i)
      #     i.jsi_each_descendent_node.group_by(&:jsi_schemas).map do |ss, vs|
      #       ss_s = ss.map do |s|
      #         name = s.jsi_schema_module_name_from_ancestor || raise("no name. root node: #{s.jsi_root_node.jsi_ptr} #{s.jsi_schema_dynamic_anchor_map.anchor_schemas_identifier}")
      #         name.sub(/^(\w)/) { $1.downcase }
      #       end.join(', ')
      #       si = vs.sort_by { |v| [v.jsi_ptr.tokens.size, v.jsi_ptr.tokens] }.first
      #       sps = si.jsi_ptr.tokens.join(' ')
      #       "{ind: #{indname}, ptr: %w(#{sps}),#{' ' * [22 - sps.size, 1].max}schemas: [#{ss_s}],#{' ' * [120 - ss_s.size, 1].max}line: __LINE__},"
      #     end
      #   end
      #   exps('x', build(x.new_jsi({}), 3))
      #   exps('rxa', build(x.new_jsi({}), 3))
      # - paste in exps, review, cleanup


      # x: document root schema with id, no dynamicAnchor
      # y: subschema of x with id, no dynamicAnchor
      # z: subschema of y with no id, dynamicAnchor: a
      # w: subschema of z with id, dynamicAnchor: b
      x = JSI.new_schema({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tag:n7/x",
        "properties": {
          "wabs":    {"$ref": "tag:n7/w"},
          "wptr":    {"$ref": "#/$defs/y/$defs/z/$defs/w"},
          "yabs":    {"$ref": "tag:n7/y"},
          "yptr":    {"$ref": "#/$defs/y"},
          "xabs":    {"$ref": "tag:n7/x"},
          "xptr":    {"$ref": "#"},
          "zabsptr": {"$ref": "tag:n7/y#/$defs/z"},
          "zptr":    {"$ref": "#/$defs/y/$defs/z"},
        },
        "$defs": {
          "y": {
            "$id": "tag:n7/y",
            "properties": {
              "wabs":    {"$ref": "tag:n7/w"},
              "wptr":    {"$ref": "#/$defs/z/$defs/w"},
              "yabs":    {"$ref": "tag:n7/y"},
              "yptr":    {"$ref": "#"},
              "x":       {"$ref": "tag:n7/x"},
              "zabsptr": {"$ref": "tag:n7/y#/$defs/z"},
              "zptr":    {"$ref": "#/$defs/z"},
            },
            "$defs": {
              "z": {
                "$dynamicAnchor": "a",
                "properties": {
                  "wabs":    {"$ref": "tag:n7/w"},
                  "wptr":    {"$ref": "#/$defs/z/$defs/w"},
                  "yabs":    {"$ref": "tag:n7/y"},
                  "yptr":    {"$ref": "#"},
                  "x":       {"$ref": "tag:n7/x"},
                  "zabsptr": {"$ref": "tag:n7/y#/$defs/z"},
                  "zptr":    {"$ref": "#/$defs/z"},
                },
                "$defs": {
                  "w": {
                    "$id": "tag:n7/w",
                    "$dynamicAnchor": "b",
                    "properties": {
                      "wabs": {"$ref": "tag:n7/w"},
                      "wptr": {"$ref": "#"},
                      "y":    {"$ref": "tag:n7/y"},
                      "x":    {"$ref": "tag:n7/x"},
                      "z":    {"$ref": "tag:n7/y#/$defs/z"},
                    },
                  },
                },
              },
            },
          },
        },
      })

      y = x['$defs']['y']
      z = x['$defs']['y']['$defs']['z']
      w = x['$defs']['y']['$defs']['z']['$defs']['w']
      x«y» = x.with_dynamic_scope_from(y)
      x«w» = x.with_dynamic_scope_from(w)
      y«w» = y.with_dynamic_scope_from(w)
      w«y» = w.with_dynamic_scope_from(y)
      x«y«w»» = x.with_dynamic_scope_from(y«w»)

      # create a schema with a $ref to ref and dynamic scope mapping each of *anchors to a subschema
      mkrefschema = proc do |ref, *anchors|
        JSI.new_schema({
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$ref": ref,
          "$defs": anchors.map { |a| [a, {"$dynamicAnchor": a}] }.to_h,
        })
      end

      rxa = mkrefschema["tag:n7/x", "a"]
      rxb = mkrefschema["tag:n7/x", "b"]
      rxab = mkrefschema["tag:n7/x", "a", "b"]
      rya = mkrefschema["tag:n7/y", "a"]
      ryb = mkrefschema["tag:n7/y", "b"]
      ryab = mkrefschema["tag:n7/y", "a", "b"]
      rza = mkrefschema["tag:n7/y#/$defs/z", "a"]
      rzb = mkrefschema["tag:n7/y#/$defs/z", "b"]
      rzab = mkrefschema["tag:n7/y#/$defs/z", "a", "b"]
      rwa = mkrefschema["tag:n7/w", "a"]
      rwb = mkrefschema["tag:n7/w", "b"]
      rwab = mkrefschema["tag:n7/w", "a", "b"]

      x«rxa» = x.with_dynamic_scope_from(rxa)
      y«rxa» = y.with_dynamic_scope_from(rxa)
      w«rxa» = w.with_dynamic_scope_from(rxa)
      #w«y«rxa»» = w.with_dynamic_scope_from(y«rxa»)
      y«w«rxa»» = y.with_dynamic_scope_from(w«rxa»)
      x«w«rxa»» = x.with_dynamic_scope_from(w«rxa»)
      #x«y«rxa»» = x.with_dynamic_scope_from(y«rxa»)

      x«rxb» = x.with_dynamic_scope_from(rxb)
      y«rxb» = y.with_dynamic_scope_from(rxb)
      w«rxb» = w.with_dynamic_scope_from(rxb)
      w«y«rxb»» = w.with_dynamic_scope_from(y«rxb»)
      #y«w«rxb»» = y.with_dynamic_scope_from(w«rxb»)
      #x«w«rxb»» = x.with_dynamic_scope_from(w«rxb»)
      x«y«rxb»» = x.with_dynamic_scope_from(y«rxb»)

      x«rxab» = x.with_dynamic_scope_from(rxab)
      y«rxab» = y.with_dynamic_scope_from(rxab)
      w«rxab» = w.with_dynamic_scope_from(rxab)
      #y«w«rxab»» = y.with_dynamic_scope_from(w«rxab»)
      #x«w«rxab»» = x.with_dynamic_scope_from(w«rxab»)

      x«rya» = x.with_dynamic_scope_from(rya)
      y«rya» = y.with_dynamic_scope_from(rya)
      w«rya» = w.with_dynamic_scope_from(rya)
      #w«y«rya»» = w.with_dynamic_scope_from(y«rya»)
      y«w«rya»» = y.with_dynamic_scope_from(w«rya»)
      x«w«rya»» = x.with_dynamic_scope_from(w«rya»)
      #x«y«rya»» = x.with_dynamic_scope_from(y«rya»)

      #x«ryb» = x.with_dynamic_scope_from(ryb)
      y«ryb» = y.with_dynamic_scope_from(ryb)
      #w«ryb» = w.with_dynamic_scope_from(ryb)
      w«y«ryb»» = w.with_dynamic_scope_from(y«ryb»)
      #y«w«ryb»» = y.with_dynamic_scope_from(w«ryb»)
      #x«w«ryb»» = x.with_dynamic_scope_from(w«ryb»)
      x«y«ryb»» = x.with_dynamic_scope_from(y«ryb»)

      x«ryab» = x.with_dynamic_scope_from(ryab)
      y«ryab» = y.with_dynamic_scope_from(ryab)
      w«ryab» = w.with_dynamic_scope_from(ryab)
      #w«y«ryab»» = w.with_dynamic_scope_from(y«ryab»)
      #y«w«ryab»» = y.with_dynamic_scope_from(w«ryab»)
      #x«w«ryab»» = x.with_dynamic_scope_from(w«ryab»)
      #x«y«ryab»» = x.with_dynamic_scope_from(y«ryab»)

      x«rza» = x.with_dynamic_scope_from(rza)
      y«rza» = y.with_dynamic_scope_from(rza)
      w«rza» = w.with_dynamic_scope_from(rza)
      #w«y«rza»» = w.with_dynamic_scope_from(y«rza»)
      y«w«rza»» = y.with_dynamic_scope_from(w«rza»)
      x«w«rza»» = x.with_dynamic_scope_from(w«rza»)
      #x«y«rza»» = x.with_dynamic_scope_from(y«rza»)

      #x«rzb» = x.with_dynamic_scope_from(rzb)
      y«rzb» = y.with_dynamic_scope_from(rzb)
      #w«rzb» = w.with_dynamic_scope_from(rzb)
      w«y«rzb»» = w.with_dynamic_scope_from(y«rzb»)
      #y«w«rzb»» = y.with_dynamic_scope_from(w«rzb»)
      #x«w«rzb»» = x.with_dynamic_scope_from(w«rzb»)
      x«y«rzb»» = x.with_dynamic_scope_from(y«rzb»)

      x«rzab» = x.with_dynamic_scope_from(rzab)
      y«rzab» = y.with_dynamic_scope_from(rzab)
      w«rzab» = w.with_dynamic_scope_from(rzab)
      #w«y«rzab»» = w.with_dynamic_scope_from(y«rzab»)
      #y«w«rzab»» = y.with_dynamic_scope_from(w«rzab»)
      #x«w«rzab»» = x.with_dynamic_scope_from(w«rzab»)
      #x«y«rzab»» = x.with_dynamic_scope_from(y«rzab»)

      #x«rwa» = x.with_dynamic_scope_from(rwa)
      #y«rwa» = y.with_dynamic_scope_from(rwa)
      w«rwa» = w.with_dynamic_scope_from(rwa)
      #w«y«rwa»» = w.with_dynamic_scope_from(y«rwa»)
      y«w«rwa»» = y.with_dynamic_scope_from(w«rwa»)
      x«w«rwa»» = x.with_dynamic_scope_from(w«rwa»)
      #x«y«rwa»» = x.with_dynamic_scope_from(y«rwa»)

      x«rwb» = x.with_dynamic_scope_from(rwb)
      y«rwb» = y.with_dynamic_scope_from(rwb)
      w«rwb» = w.with_dynamic_scope_from(rwb)
      w«y«rwb»» = w.with_dynamic_scope_from(y«rwb»)
      #y«w«rwb»» = y.with_dynamic_scope_from(w«rwb»)
      #x«w«rwb»» = x.with_dynamic_scope_from(w«rwb»)
      x«y«rwb»» = x.with_dynamic_scope_from(y«rwb»)

      x«rwab» = x.with_dynamic_scope_from(rwab)
      y«rwab» = y.with_dynamic_scope_from(rwab)
      w«rwab» = w.with_dynamic_scope_from(rwab)
      #w«y«rwab»» = w.with_dynamic_scope_from(y«rwab»)
      #y«w«rwab»» = y.with_dynamic_scope_from(w«rwab»)
      #x«w«rwab»» = x.with_dynamic_scope_from(w«rwab»)
      #x«y«rwab»» = x.with_dynamic_scope_from(y«rwab»)

      exps = [
        {ind: x, ptr: %w(),                      schemas: [x],                                                                                                                           line: __LINE__},
        {ind: x, ptr: %w(wabs),                  schemas: [x.properties["wabs"], w],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs wabs),             schemas: [w.properties["wabs"], w],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs wptr),             schemas: [w.properties["wptr"], w],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs y),                schemas: [w.properties["y"], y«w»],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs x),                schemas: [w.properties["x"], x«w»],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs z),                schemas: [w.properties["z"], y«w»["$defs"]["z"]],                                                                                       line: __LINE__},
        {ind: x, ptr: %w(wabs y wabs),           schemas: [y«w».properties["wabs"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y wptr),           schemas: [y«w».properties["wptr"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y yabs),           schemas: [y«w».properties["yabs"], y«w»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y yptr),           schemas: [y«w».properties["yptr"], y«w»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y x),              schemas: [y«w».properties["x"], x«y«w»»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y zabsptr),        schemas: [y«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs y zptr),           schemas: [y«w».properties["zptr"], y«w»["$defs"]["z"]],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x wabs),           schemas: [x«w».properties["wabs"], w],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr),           schemas: [x«w».properties["wptr"], x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs x yabs),           schemas: [x«w».properties["yabs"], y«w»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr),           schemas: [x«w».properties["yptr"], x«w»["$defs"]["y"]],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x xabs),           schemas: [x«w».properties["xabs"], x«w»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs x xptr),           schemas: [x«w».properties["xptr"], x«w»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(wabs x zabsptr),        schemas: [x«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr),           schemas: [x«w».properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs z wabs),           schemas: [y«w»["$defs"]["z"].properties["wabs"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs z wptr),           schemas: [y«w»["$defs"]["z"].properties["wptr"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs z yabs),           schemas: [y«w»["$defs"]["z"].properties["yabs"], y«w»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs z yptr),           schemas: [y«w»["$defs"]["z"].properties["yptr"], y«w»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs z x),              schemas: [y«w»["$defs"]["z"].properties["x"], x«y«w»»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs z zabsptr),        schemas: [y«w»["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs z zptr),           schemas: [y«w»["$defs"]["z"].properties["zptr"], y«w»["$defs"]["z"]],                                                                   line: __LINE__},
        {ind: x, ptr: %w(yabs wabs wabs),        schemas: [w«y».properties["wabs"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs wabs wptr),        schemas: [w«y».properties["wptr"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs wabs y),           schemas: [w«y».properties["y"], y«w»],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(yabs wabs x),           schemas: [w«y».properties["x"], x«y«w»»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs wabs z),           schemas: [w«y».properties["z"], y«w»["$defs"]["z"]],                                                                                    line: __LINE__},
        {ind: x, ptr: %w(wabs y x wabs),         schemas: [x«y«w»».properties["wabs"], w«y»],                                                                                            line: __LINE__},
        {ind: x, ptr: %w(wabs y x wptr),         schemas: [x«y«w»».properties["wptr"], w«y»],                                                                                            line: __LINE__},
        {ind: x, ptr: %w(wabs y x yabs),         schemas: [x«y«w»».properties["yabs"], y«w»],                                                                                            line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr),         schemas: [x«y«w»».properties["yptr"], x«y«w»»["$defs"]["y"]],                                                                           line: __LINE__},
        {ind: x, ptr: %w(wabs y x xabs),         schemas: [x«y«w»».properties["xabs"], x«y«w»»],                                                                                         line: __LINE__},
        {ind: x, ptr: %w(wabs y x xptr),         schemas: [x«y«w»».properties["xptr"], x«y«w»»],                                                                                         line: __LINE__},
        {ind: x, ptr: %w(wabs y x zabsptr),      schemas: [x«y«w»».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                           line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr),         schemas: [x«y«w»».properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                                             line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr wabs),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w],                                                        line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr wptr),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],           line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr y),         schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w»],                                                        line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr x),         schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w»],                                                        line: __LINE__},
        {ind: x, ptr: %w(wabs x wptr z),         schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w»["$defs"]["z"]],                                          line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr wabs),      schemas: [x«w»["$defs"]["y"].properties["wabs"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr wptr),      schemas: [x«w»["$defs"]["y"].properties["wptr"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr yabs),      schemas: [x«w»["$defs"]["y"].properties["yabs"], y«w»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr yptr),      schemas: [x«w»["$defs"]["y"].properties["yptr"], x«w»["$defs"]["y"]],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr x),         schemas: [x«w»["$defs"]["y"].properties["x"], x«y«w»»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr zabsptr),   schemas: [x«w»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs x yptr zptr),      schemas: [x«w»["$defs"]["y"].properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr wabs),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr wptr),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr yabs),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr yptr),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w»["$defs"]["y"]],                                                     line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr x),         schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr zabsptr),   schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                  line: __LINE__},
        {ind: x, ptr: %w(wabs x zptr zptr),      schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                       line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr wabs),    schemas: [x«y«w»»["$defs"]["y"].properties["wabs"], w«y»],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr wptr),    schemas: [x«y«w»»["$defs"]["y"].properties["wptr"], w«y»],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr yabs),    schemas: [x«y«w»»["$defs"]["y"].properties["yabs"], y«w»],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr yptr),    schemas: [x«y«w»»["$defs"]["y"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                                             line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr x),       schemas: [x«y«w»»["$defs"]["y"].properties["x"], x«y«w»»],                                                                              line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr zabsptr), schemas: [x«y«w»»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                             line: __LINE__},
        {ind: x, ptr: %w(wabs y x yptr zptr),    schemas: [x«y«w»»["$defs"]["y"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr wabs),    schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr wptr),    schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr yabs),    schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr yptr),    schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr x),       schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                                line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr zabsptr), schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                               line: __LINE__},
        {ind: x, ptr: %w(wabs y x zptr zptr),    schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                 line: __LINE__},
        {ind: x, ptr: %w(wptr),                  schemas: [x.properties["wptr"], w],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs),                  schemas: [x.properties["yabs"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs wabs),             schemas: [y.properties["wabs"], w«y»],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(yabs wptr),             schemas: [y.properties["wptr"], w«y»],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(yabs yabs),             schemas: [y.properties["yabs"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs yptr),             schemas: [y.properties["yptr"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs x),                schemas: [y.properties["x"], x«y»],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs zabsptr),          schemas: [y.properties["zabsptr"], z],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(yabs zptr),             schemas: [y.properties["zptr"], z],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs x wabs),           schemas: [x«y».properties["wabs"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs x wptr),           schemas: [x«y».properties["wptr"], w«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs x yabs),           schemas: [x«y».properties["yabs"], y],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr),           schemas: [x«y».properties["yptr"], x«y»["$defs"]["y"]],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(yabs x xabs),           schemas: [x«y».properties["xabs"], x«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs x xptr),           schemas: [x«y».properties["xptr"], x«y»],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs x zabsptr),        schemas: [x«y».properties["zabsptr"], z],                                                                                               line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr),           schemas: [x«y».properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                                   line: __LINE__},
        {ind: x, ptr: %w(zabsptr wabs),          schemas: [z.properties["wabs"], w«y»],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(zabsptr wptr),          schemas: [z.properties["wptr"], w«y»],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(zabsptr yabs),          schemas: [z.properties["yabs"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(zabsptr yptr),          schemas: [z.properties["yptr"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(zabsptr x),             schemas: [z.properties["x"], x«y»],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(zabsptr zabsptr),       schemas: [z.properties["zabsptr"], z],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(zabsptr zptr),          schemas: [z.properties["zptr"], z],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr wabs),      schemas: [x«y»["$defs"]["y"].properties["wabs"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr wptr),      schemas: [x«y»["$defs"]["y"].properties["wptr"], w«y»],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr yabs),      schemas: [x«y»["$defs"]["y"].properties["yabs"], y],                                                                                    line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr yptr),      schemas: [x«y»["$defs"]["y"].properties["yptr"], x«y»["$defs"]["y"]],                                                                   line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr x),         schemas: [x«y»["$defs"]["y"].properties["x"], x«y»],                                                                                    line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr zabsptr),   schemas: [x«y»["$defs"]["y"].properties["zabsptr"], z],                                                                                 line: __LINE__},
        {ind: x, ptr: %w(yabs x yptr zptr),      schemas: [x«y»["$defs"]["y"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr wabs),      schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr wptr),      schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                                   line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr yabs),      schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y],                                                                      line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr yptr),      schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y»["$defs"]["y"]],                                                     line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr x),         schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y»],                                                                      line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr zabsptr),   schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], z],                                                                   line: __LINE__},
        {ind: x, ptr: %w(yabs x zptr zptr),      schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                       line: __LINE__},
        {ind: x, ptr: %w(yptr),                  schemas: [x.properties["yptr"], y],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(xabs),                  schemas: [x.properties["xabs"], x],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(xptr),                  schemas: [x.properties["xptr"], x],                                                                                                     line: __LINE__},
        {ind: x, ptr: %w(zabsptr),               schemas: [x.properties["zabsptr"], z],                                                                                                  line: __LINE__},
        {ind: x, ptr: %w(zptr),                  schemas: [x.properties["zptr"], z],                                                                                                     line: __LINE__},

        {ind: rxa, ptr: %w(),                    schemas: [rxa, x«rxa»],                                                                                                                 line: __LINE__},
        {ind: rxa, ptr: %w(wabs),                schemas: [x«rxa».properties["wabs"], w«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs wabs),           schemas: [w«rxa».properties["wabs"], w«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs wptr),           schemas: [w«rxa».properties["wptr"], w«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs y),              schemas: [w«rxa».properties["y"], y«w«rxa»»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs x),              schemas: [w«rxa».properties["x"], x«w«rxa»»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs z),              schemas: [w«rxa».properties["z"], y«w«rxa»»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wabs),         schemas: [y«w«rxa»».properties["wabs"], w«rxa»],                                                                                        line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr),         schemas: [y«w«rxa»».properties["wptr"], y«w«rxa»»["$defs"]["z"]["$defs"]["w"]],                                                         line: __LINE__},
        {ind: rxa, ptr: %w(wabs y yabs),         schemas: [y«w«rxa»».properties["yabs"], y«w«rxa»»],                                                                                     line: __LINE__},
        {ind: rxa, ptr: %w(wabs y yptr),         schemas: [y«w«rxa»».properties["yptr"], y«w«rxa»»],                                                                                     line: __LINE__},
        {ind: rxa, ptr: %w(wabs y x),            schemas: [y«w«rxa»».properties["x"], x«w«rxa»»],                                                                                        line: __LINE__},
        {ind: rxa, ptr: %w(wabs y zabsptr),      schemas: [y«w«rxa»».properties["zabsptr"], y«w«rxa»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rxa, ptr: %w(wabs y zptr),         schemas: [y«w«rxa»».properties["zptr"], y«w«rxa»»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wabs),         schemas: [x«w«rxa»».properties["wabs"], w«rxa»],                                                                                        line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr),         schemas: [x«w«rxa»».properties["wptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yabs),         schemas: [x«w«rxa»».properties["yabs"], y«w«rxa»»],                                                                                     line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr),         schemas: [x«w«rxa»».properties["yptr"], x«w«rxa»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rxa, ptr: %w(wabs x xabs),         schemas: [x«w«rxa»».properties["xabs"], x«w«rxa»»],                                                                                     line: __LINE__},
        {ind: rxa, ptr: %w(wabs x xptr),         schemas: [x«w«rxa»».properties["xptr"], x«w«rxa»»],                                                                                     line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zabsptr),      schemas: [x«w«rxa»».properties["zabsptr"], y«w«rxa»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr),         schemas: [x«w«rxa»».properties["zptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rxa, ptr: %w(wabs z wabs),         schemas: [y«w«rxa»»["$defs"]["z"].properties["wabs"], w«rxa»],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(wabs z wptr),         schemas: [y«w«rxa»»["$defs"]["z"].properties["wptr"], y«w«rxa»»["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs z yabs),         schemas: [y«w«rxa»»["$defs"]["z"].properties["yabs"], y«w«rxa»»],                                                                       line: __LINE__},
        {ind: rxa, ptr: %w(wabs z yptr),         schemas: [y«w«rxa»»["$defs"]["z"].properties["yptr"], y«w«rxa»»],                                                                       line: __LINE__},
        {ind: rxa, ptr: %w(wabs z x),            schemas: [y«w«rxa»»["$defs"]["z"].properties["x"], x«w«rxa»»],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(wabs z zabsptr),      schemas: [y«w«rxa»»["$defs"]["z"].properties["zabsptr"], y«w«rxa»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rxa, ptr: %w(wabs z zptr),         schemas: [y«w«rxa»»["$defs"]["z"].properties["zptr"], y«w«rxa»»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr wabs),    schemas: [y«w«rxa»»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxa»],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr wptr),    schemas: [y«w«rxa»»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«w«rxa»»["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr y),       schemas: [y«w«rxa»»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rxa»»],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr x),       schemas: [y«w«rxa»»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rxa»»],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(wabs y wptr z),       schemas: [y«w«rxa»»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rxa»»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr wabs),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxa»],                                              line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr wptr),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]], line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr y),       schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rxa»»],                                              line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr x),       schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rxa»»],                                              line: __LINE__},
        {ind: rxa, ptr: %w(wabs x wptr z),       schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rxa»»["$defs"]["z"]],                                line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr wabs),    schemas: [x«w«rxa»»["$defs"]["y"].properties["wabs"], w«rxa»],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr wptr),    schemas: [x«w«rxa»»["$defs"]["y"].properties["wptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr yabs),    schemas: [x«w«rxa»»["$defs"]["y"].properties["yabs"], y«w«rxa»»],                                                                       line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr yptr),    schemas: [x«w«rxa»»["$defs"]["y"].properties["yptr"], x«w«rxa»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr x),       schemas: [x«w«rxa»»["$defs"]["y"].properties["x"], x«w«rxa»»],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr zabsptr), schemas: [x«w«rxa»»["$defs"]["y"].properties["zabsptr"], y«w«rxa»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rxa, ptr: %w(wabs x yptr zptr),    schemas: [x«w«rxa»»["$defs"]["y"].properties["zptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr wabs),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rxa»],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr wptr),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],               line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr yabs),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w«rxa»»],                                                         line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr yptr),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w«rxa»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr x),       schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«w«rxa»»],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr zabsptr), schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w«rxa»»["$defs"]["z"]],                                        line: __LINE__},
        {ind: rxa, ptr: %w(wabs x zptr zptr),    schemas: [x«w«rxa»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w«rxa»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},
        {ind: rxa, ptr: %w(wptr),                schemas: [x«rxa».properties["wptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(wptr wabs),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxa»],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(wptr wptr),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: rxa, ptr: %w(wptr y),              schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rxa»»],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(wptr x),              schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rxa»»],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(wptr z),              schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rxa»»["$defs"]["z"]],                                   line: __LINE__},
        {ind: rxa, ptr: %w(yabs),                schemas: [x«rxa».properties["yabs"], y«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(yabs wabs),           schemas: [y«rxa».properties["wabs"], w«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr),           schemas: [y«rxa».properties["wptr"], y«rxa»["$defs"]["z"]["$defs"]["w"]],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr wabs),      schemas: [y«rxa»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxa»],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr wptr),      schemas: [y«rxa»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rxa»["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr y),         schemas: [y«rxa»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rxa»»],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr x),         schemas: [y«rxa»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rxa»»],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yabs wptr z),         schemas: [y«rxa»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rxa»»["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(yabs yabs),           schemas: [y«rxa».properties["yabs"], y«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(yabs yptr),           schemas: [y«rxa».properties["yptr"], y«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(yabs x),              schemas: [y«rxa».properties["x"], x«rxa»],                                                                                              line: __LINE__},
        {ind: rxa, ptr: %w(yabs zabsptr),        schemas: [y«rxa».properties["zabsptr"], y«rxa»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(yabs zptr),           schemas: [y«rxa».properties["zptr"], y«rxa»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(yptr),                schemas: [x«rxa».properties["yptr"], x«rxa»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(xabs),                schemas: [x«rxa».properties["xabs"], x«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(xptr),                schemas: [x«rxa».properties["xptr"], x«rxa»],                                                                                           line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr),             schemas: [x«rxa».properties["zabsptr"], y«rxa»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rxa, ptr: %w(zptr),                schemas: [x«rxa».properties["zptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr wabs),        schemas: [y«rxa»["$defs"]["z"].properties["wabs"], w«rxa»],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr wptr),        schemas: [y«rxa»["$defs"]["z"].properties["wptr"], y«rxa»["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr yabs),        schemas: [y«rxa»["$defs"]["z"].properties["yabs"], y«rxa»],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr yptr),        schemas: [y«rxa»["$defs"]["z"].properties["yptr"], y«rxa»],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr x),           schemas: [y«rxa»["$defs"]["z"].properties["x"], x«rxa»],                                                                                line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr zabsptr),     schemas: [y«rxa»["$defs"]["z"].properties["zabsptr"], y«rxa»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(zabsptr zptr),        schemas: [y«rxa»["$defs"]["z"].properties["zptr"], y«rxa»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yptr wabs),           schemas: [x«rxa»["$defs"]["y"].properties["wabs"], w«rxa»],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(yptr wptr),           schemas: [x«rxa»["$defs"]["y"].properties["wptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rxa, ptr: %w(yptr yabs),           schemas: [x«rxa»["$defs"]["y"].properties["yabs"], y«rxa»],                                                                             line: __LINE__},
        {ind: rxa, ptr: %w(yptr yptr),           schemas: [x«rxa»["$defs"]["y"].properties["yptr"], x«rxa»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(yptr x),              schemas: [x«rxa»["$defs"]["y"].properties["x"], x«rxa»],                                                                                line: __LINE__},
        {ind: rxa, ptr: %w(yptr zabsptr),        schemas: [x«rxa»["$defs"]["y"].properties["zabsptr"], y«rxa»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rxa, ptr: %w(yptr zptr),           schemas: [x«rxa»["$defs"]["y"].properties["zptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(zptr wabs),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rxa»],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(zptr wptr),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                     line: __LINE__},
        {ind: rxa, ptr: %w(zptr yabs),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rxa»],                                                               line: __LINE__},
        {ind: rxa, ptr: %w(zptr yptr),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rxa»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: rxa, ptr: %w(zptr x),              schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rxa»],                                                                  line: __LINE__},
        {ind: rxa, ptr: %w(zptr zabsptr),        schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rxa»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rxa, ptr: %w(zptr zptr),           schemas: [x«rxa»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rxa»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},

        {ind: rxb, ptr: %w(),                    schemas: [rxb, x«rxb»],                                                                                                                 line: __LINE__},
        {ind: rxb, ptr: %w(wabs),                schemas: [x«rxb».properties["wabs"], w«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(wabs wabs),           schemas: [w«rxb».properties["wabs"], w«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(wabs wptr),           schemas: [w«rxb».properties["wptr"], w«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(wabs y),              schemas: [w«rxb».properties["y"], y«rxb»],                                                                                              line: __LINE__},
        {ind: rxb, ptr: %w(wabs x),              schemas: [w«rxb».properties["x"], x«rxb»],                                                                                              line: __LINE__},
        {ind: rxb, ptr: %w(wabs z),              schemas: [w«rxb».properties["z"], y«rxb»["$defs"]["z"]],                                                                                line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs),           schemas: [y«rxb».properties["wabs"], w«y«rxb»»],                                                                                        line: __LINE__},
        {ind: rxb, ptr: %w(yabs wptr),           schemas: [y«rxb».properties["wptr"], w«y«rxb»»],                                                                                        line: __LINE__},
        {ind: rxb, ptr: %w(yabs yabs),           schemas: [y«rxb».properties["yabs"], y«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs yptr),           schemas: [y«rxb».properties["yptr"], y«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs x),              schemas: [y«rxb».properties["x"], x«y«rxb»»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs zabsptr),        schemas: [y«rxb».properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(yabs zptr),           schemas: [y«rxb».properties["zptr"], y«rxb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(wptr),                schemas: [x«rxb».properties["wptr"], x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rxb, ptr: %w(yabs),                schemas: [x«rxb».properties["yabs"], y«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(yptr),                schemas: [x«rxb».properties["yptr"], x«rxb»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(xabs),                schemas: [x«rxb».properties["xabs"], x«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(xptr),                schemas: [x«rxb».properties["xptr"], x«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr),             schemas: [x«rxb».properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(zptr),                schemas: [x«rxb».properties["zptr"], x«rxb»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr wabs),        schemas: [y«rxb»["$defs"]["z"].properties["wabs"], w«y«rxb»»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr wptr),        schemas: [y«rxb»["$defs"]["z"].properties["wptr"], w«y«rxb»»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr yabs),        schemas: [y«rxb»["$defs"]["z"].properties["yabs"], y«rxb»],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr yptr),        schemas: [y«rxb»["$defs"]["z"].properties["yptr"], y«rxb»],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr x),           schemas: [y«rxb»["$defs"]["z"].properties["x"], x«y«rxb»»],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr zabsptr),     schemas: [y«rxb»["$defs"]["z"].properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(zabsptr zptr),        schemas: [y«rxb»["$defs"]["z"].properties["zptr"], y«rxb»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs wabs),      schemas: [w«y«rxb»».properties["wabs"], w«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs wptr),      schemas: [w«y«rxb»».properties["wptr"], w«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs y),         schemas: [w«y«rxb»».properties["y"], y«rxb»],                                                                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs x),         schemas: [w«y«rxb»».properties["x"], x«y«rxb»»],                                                                                        line: __LINE__},
        {ind: rxb, ptr: %w(yabs wabs z),         schemas: [w«y«rxb»».properties["z"], y«rxb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(yabs x wabs),         schemas: [x«y«rxb»».properties["wabs"], w«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs x wptr),         schemas: [x«y«rxb»».properties["wptr"], w«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yabs),         schemas: [x«y«rxb»».properties["yabs"], y«rxb»],                                                                                        line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr),         schemas: [x«y«rxb»».properties["yptr"], x«y«rxb»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rxb, ptr: %w(yabs x xabs),         schemas: [x«y«rxb»».properties["xabs"], x«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs x xptr),         schemas: [x«y«rxb»».properties["xptr"], x«y«rxb»»],                                                                                     line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zabsptr),      schemas: [x«y«rxb»».properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr),         schemas: [x«y«rxb»».properties["zptr"], x«y«rxb»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rxb, ptr: %w(wptr wabs),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxb»],                                                 line: __LINE__},
        {ind: rxb, ptr: %w(wptr wptr),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: rxb, ptr: %w(wptr y),              schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«rxb»],                                                    line: __LINE__},
        {ind: rxb, ptr: %w(wptr x),              schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«rxb»],                                                    line: __LINE__},
        {ind: rxb, ptr: %w(wptr z),              schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«rxb»["$defs"]["z"]],                                      line: __LINE__},
        {ind: rxb, ptr: %w(yptr wabs),           schemas: [x«rxb»["$defs"]["y"].properties["wabs"], w«y«rxb»»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(yptr wptr),           schemas: [x«rxb»["$defs"]["y"].properties["wptr"], w«y«rxb»»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(yptr yabs),           schemas: [x«rxb»["$defs"]["y"].properties["yabs"], y«rxb»],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(yptr yptr),           schemas: [x«rxb»["$defs"]["y"].properties["yptr"], x«rxb»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: rxb, ptr: %w(yptr x),              schemas: [x«rxb»["$defs"]["y"].properties["x"], x«y«rxb»»],                                                                             line: __LINE__},
        {ind: rxb, ptr: %w(yptr zabsptr),        schemas: [x«rxb»["$defs"]["y"].properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(yptr zptr),           schemas: [x«rxb»["$defs"]["y"].properties["zptr"], x«rxb»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rxb, ptr: %w(zptr wabs),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«rxb»»],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(zptr wptr),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«rxb»»],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(zptr yabs),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rxb»],                                                               line: __LINE__},
        {ind: rxb, ptr: %w(zptr yptr),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rxb»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: rxb, ptr: %w(zptr x),              schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«rxb»»],                                                               line: __LINE__},
        {ind: rxb, ptr: %w(zptr zabsptr),        schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rxb»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rxb, ptr: %w(zptr zptr),           schemas: [x«rxb»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rxb»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr wabs),    schemas: [x«y«rxb»»["$defs"]["y"].properties["wabs"], w«y«rxb»»],                                                                       line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr wptr),    schemas: [x«y«rxb»»["$defs"]["y"].properties["wptr"], w«y«rxb»»],                                                                       line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr yabs),    schemas: [x«y«rxb»»["$defs"]["y"].properties["yabs"], y«rxb»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr yptr),    schemas: [x«y«rxb»»["$defs"]["y"].properties["yptr"], x«y«rxb»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr x),       schemas: [x«y«rxb»»["$defs"]["y"].properties["x"], x«y«rxb»»],                                                                          line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr zabsptr), schemas: [x«y«rxb»»["$defs"]["y"].properties["zabsptr"], y«rxb»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rxb, ptr: %w(yabs x yptr zptr),    schemas: [x«y«rxb»»["$defs"]["y"].properties["zptr"], x«y«rxb»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr wabs),    schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«rxb»»],                                                         line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr wptr),    schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«rxb»»],                                                         line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr yabs),    schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rxb»],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr yptr),    schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«rxb»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr x),       schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«rxb»»],                                                            line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr zabsptr), schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rxb»["$defs"]["z"]],                                           line: __LINE__},
        {ind: rxb, ptr: %w(yabs x zptr zptr),    schemas: [x«y«rxb»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«rxb»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: rxab, ptr: %w(),                schemas: [rxab, x«rxab»],                                                                                                               line: __LINE__},
        {ind: rxab, ptr: %w(wabs),            schemas: [x«rxab».properties["wabs"], w«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(wabs wabs),       schemas: [w«rxab».properties["wabs"], w«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(wabs wptr),       schemas: [w«rxab».properties["wptr"], w«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(wabs y),          schemas: [w«rxab».properties["y"], y«rxab»],                                                                                            line: __LINE__},
        {ind: rxab, ptr: %w(wabs x),          schemas: [w«rxab».properties["x"], x«rxab»],                                                                                            line: __LINE__},
        {ind: rxab, ptr: %w(wabs z),          schemas: [w«rxab».properties["z"], y«rxab»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: rxab, ptr: %w(yabs wabs),       schemas: [y«rxab».properties["wabs"], w«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr),       schemas: [y«rxab».properties["wptr"], y«rxab»["$defs"]["z"]["$defs"]["w"]],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(yabs yabs),       schemas: [y«rxab».properties["yabs"], y«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(yabs yptr),       schemas: [y«rxab».properties["yptr"], y«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(yabs x),          schemas: [y«rxab».properties["x"], x«rxab»],                                                                                            line: __LINE__},
        {ind: rxab, ptr: %w(yabs zabsptr),    schemas: [y«rxab».properties["zabsptr"], y«rxab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rxab, ptr: %w(yabs zptr),       schemas: [y«rxab».properties["zptr"], y«rxab»["$defs"]["z"]],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(wptr),            schemas: [x«rxab».properties["wptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rxab, ptr: %w(yabs),            schemas: [x«rxab».properties["yabs"], y«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(yptr),            schemas: [x«rxab».properties["yptr"], x«rxab»["$defs"]["y"]],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(xabs),            schemas: [x«rxab».properties["xabs"], x«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(xptr),            schemas: [x«rxab».properties["xptr"], x«rxab»],                                                                                         line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr),         schemas: [x«rxab».properties["zabsptr"], y«rxab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rxab, ptr: %w(zptr),            schemas: [x«rxab».properties["zptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr wabs),    schemas: [y«rxab»["$defs"]["z"].properties["wabs"], w«rxab»],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr wptr),    schemas: [y«rxab»["$defs"]["z"].properties["wptr"], y«rxab»["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr yabs),    schemas: [y«rxab»["$defs"]["z"].properties["yabs"], y«rxab»],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr yptr),    schemas: [y«rxab»["$defs"]["z"].properties["yptr"], y«rxab»],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr x),       schemas: [y«rxab»["$defs"]["z"].properties["x"], x«rxab»],                                                                              line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr zabsptr), schemas: [y«rxab»["$defs"]["z"].properties["zabsptr"], y«rxab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rxab, ptr: %w(zabsptr zptr),    schemas: [y«rxab»["$defs"]["z"].properties["zptr"], y«rxab»["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr wabs),  schemas: [y«rxab»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxab»],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr wptr),  schemas: [y«rxab»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rxab»["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr y),     schemas: [y«rxab»["$defs"]["z"]["$defs"]["w"].properties["y"], y«rxab»],                                                                line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr x),     schemas: [y«rxab»["$defs"]["z"]["$defs"]["w"].properties["x"], x«rxab»],                                                                line: __LINE__},
        {ind: rxab, ptr: %w(yabs wptr z),     schemas: [y«rxab»["$defs"]["z"]["$defs"]["w"].properties["z"], y«rxab»["$defs"]["z"]],                                                  line: __LINE__},
        {ind: rxab, ptr: %w(wptr wabs),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rxab»],                                               line: __LINE__},
        {ind: rxab, ptr: %w(wptr wptr),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],     line: __LINE__},
        {ind: rxab, ptr: %w(wptr y),          schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«rxab»],                                                  line: __LINE__},
        {ind: rxab, ptr: %w(wptr x),          schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«rxab»],                                                  line: __LINE__},
        {ind: rxab, ptr: %w(wptr z),          schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«rxab»["$defs"]["z"]],                                    line: __LINE__},
        {ind: rxab, ptr: %w(yptr wabs),       schemas: [x«rxab»["$defs"]["y"].properties["wabs"], w«rxab»],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(yptr wptr),       schemas: [x«rxab»["$defs"]["y"].properties["wptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rxab, ptr: %w(yptr yabs),       schemas: [x«rxab»["$defs"]["y"].properties["yabs"], y«rxab»],                                                                           line: __LINE__},
        {ind: rxab, ptr: %w(yptr yptr),       schemas: [x«rxab»["$defs"]["y"].properties["yptr"], x«rxab»["$defs"]["y"]],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(yptr x),          schemas: [x«rxab»["$defs"]["y"].properties["x"], x«rxab»],                                                                              line: __LINE__},
        {ind: rxab, ptr: %w(yptr zabsptr),    schemas: [x«rxab»["$defs"]["y"].properties["zabsptr"], y«rxab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rxab, ptr: %w(yptr zptr),       schemas: [x«rxab»["$defs"]["y"].properties["zptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]],                                               line: __LINE__},
        {ind: rxab, ptr: %w(zptr wabs),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rxab»],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(zptr wptr),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                   line: __LINE__},
        {ind: rxab, ptr: %w(zptr yabs),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rxab»],                                                             line: __LINE__},
        {ind: rxab, ptr: %w(zptr yptr),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rxab»["$defs"]["y"]],                                               line: __LINE__},
        {ind: rxab, ptr: %w(zptr x),          schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rxab»],                                                                line: __LINE__},
        {ind: rxab, ptr: %w(zptr zabsptr),    schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rxab»["$defs"]["z"]],                                            line: __LINE__},
        {ind: rxab, ptr: %w(zptr zptr),       schemas: [x«rxab»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rxab»["$defs"]["y"]["$defs"]["z"]],                                 line: __LINE__},

        {ind: y, ptr: %w(),                      schemas: [y],                                                                                                                       line: __LINE__},
        {ind: y, ptr: %w(wabs),                  schemas: [y.properties["wabs"], w«y»],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(wabs wabs),             schemas: [w«y».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs wptr),             schemas: [w«y».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y),                schemas: [w«y».properties["y"], y«w»],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(wabs x),                schemas: [w«y».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs z),                schemas: [w«y».properties["z"], y«w»["$defs"]["z"]],                                                                                line: __LINE__},
        {ind: y, ptr: %w(wabs y wabs),           schemas: [y«w».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y wptr),           schemas: [y«w».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y yabs),           schemas: [y«w».properties["yabs"], y«w»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y yptr),           schemas: [y«w».properties["yptr"], y«w»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y x),              schemas: [y«w».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(wabs y zabsptr),        schemas: [y«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: y, ptr: %w(wabs y zptr),           schemas: [y«w».properties["zptr"], y«w»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs x wabs),           schemas: [x«y«w»».properties["wabs"], w«y»],                                                                                        line: __LINE__},
        {ind: y, ptr: %w(wabs x wptr),           schemas: [x«y«w»».properties["wptr"], w«y»],                                                                                        line: __LINE__},
        {ind: y, ptr: %w(wabs x yabs),           schemas: [x«y«w»».properties["yabs"], y«w»],                                                                                        line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr),           schemas: [x«y«w»».properties["yptr"], x«y«w»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: y, ptr: %w(wabs x xabs),           schemas: [x«y«w»».properties["xabs"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: y, ptr: %w(wabs x xptr),           schemas: [x«y«w»».properties["xptr"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: y, ptr: %w(wabs x zabsptr),        schemas: [x«y«w»».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr),           schemas: [x«y«w»».properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: y, ptr: %w(wabs z wabs),           schemas: [y«w»["$defs"]["z"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs z wptr),           schemas: [y«w»["$defs"]["z"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs z yabs),           schemas: [y«w»["$defs"]["z"].properties["yabs"], y«w»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs z yptr),           schemas: [y«w»["$defs"]["z"].properties["yptr"], y«w»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs z x),              schemas: [y«w»["$defs"]["z"].properties["x"], x«y«w»»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(wabs z zabsptr),        schemas: [y«w»["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: y, ptr: %w(wabs z zptr),           schemas: [y«w»["$defs"]["z"].properties["zptr"], y«w»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr wabs),      schemas: [x«y«w»»["$defs"]["y"].properties["wabs"], w«y»],                                                                          line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr wptr),      schemas: [x«y«w»»["$defs"]["y"].properties["wptr"], w«y»],                                                                          line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr yabs),      schemas: [x«y«w»»["$defs"]["y"].properties["yabs"], y«w»],                                                                          line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr yptr),      schemas: [x«y«w»»["$defs"]["y"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr x),         schemas: [x«y«w»»["$defs"]["y"].properties["x"], x«y«w»»],                                                                          line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr zabsptr),   schemas: [x«y«w»»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: y, ptr: %w(wabs x yptr zptr),      schemas: [x«y«w»»["$defs"]["y"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr wabs),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                            line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr wptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                            line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr yabs),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                            line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr yptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr x),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                            line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr zabsptr),   schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                           line: __LINE__},
        {ind: y, ptr: %w(wabs x zptr zptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},
        {ind: y, ptr: %w(wptr),                  schemas: [y.properties["wptr"], w«y»],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(yabs),                  schemas: [y.properties["yabs"], y],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(yptr),                  schemas: [y.properties["yptr"], y],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(x),                     schemas: [y.properties["x"], x«y»],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(zabsptr),               schemas: [y.properties["zabsptr"], z],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(zptr),                  schemas: [y.properties["zptr"], z],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(x wabs),                schemas: [x«y».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(x wptr),                schemas: [x«y».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(x yabs),                schemas: [x«y».properties["yabs"], y],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(x yptr),                schemas: [x«y».properties["yptr"], x«y»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: y, ptr: %w(x xabs),                schemas: [x«y».properties["xabs"], x«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(x xptr),                schemas: [x«y».properties["xptr"], x«y»],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(x zabsptr),             schemas: [x«y».properties["zabsptr"], z],                                                                                           line: __LINE__},
        {ind: y, ptr: %w(x zptr),                schemas: [x«y».properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: y, ptr: %w(zabsptr wabs),          schemas: [z.properties["wabs"], w«y»],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(zabsptr wptr),          schemas: [z.properties["wptr"], w«y»],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(zabsptr yabs),          schemas: [z.properties["yabs"], y],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(zabsptr yptr),          schemas: [z.properties["yptr"], y],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(zabsptr x),             schemas: [z.properties["x"], x«y»],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(zabsptr zabsptr),       schemas: [z.properties["zabsptr"], z],                                                                                              line: __LINE__},
        {ind: y, ptr: %w(zabsptr zptr),          schemas: [z.properties["zptr"], z],                                                                                                 line: __LINE__},
        {ind: y, ptr: %w(x yptr wabs),           schemas: [x«y»["$defs"]["y"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(x yptr wptr),           schemas: [x«y»["$defs"]["y"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: y, ptr: %w(x yptr yabs),           schemas: [x«y»["$defs"]["y"].properties["yabs"], y],                                                                                line: __LINE__},
        {ind: y, ptr: %w(x yptr yptr),           schemas: [x«y»["$defs"]["y"].properties["yptr"], x«y»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: y, ptr: %w(x yptr x),              schemas: [x«y»["$defs"]["y"].properties["x"], x«y»],                                                                                line: __LINE__},
        {ind: y, ptr: %w(x yptr zabsptr),        schemas: [x«y»["$defs"]["y"].properties["zabsptr"], z],                                                                             line: __LINE__},
        {ind: y, ptr: %w(x yptr zptr),           schemas: [x«y»["$defs"]["y"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: y, ptr: %w(x zptr wabs),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                               line: __LINE__},
        {ind: y, ptr: %w(x zptr wptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                               line: __LINE__},
        {ind: y, ptr: %w(x zptr yabs),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y],                                                                  line: __LINE__},
        {ind: y, ptr: %w(x zptr yptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: y, ptr: %w(x zptr x),              schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y»],                                                                  line: __LINE__},
        {ind: y, ptr: %w(x zptr zabsptr),        schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], z],                                                               line: __LINE__},
        {ind: y, ptr: %w(x zptr zptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},

        {ind: rya, ptr: %w(),                    schemas: [rya, y«rya»],                                                                                                                 line: __LINE__},
        {ind: rya, ptr: %w(wabs),                schemas: [y«rya».properties["wabs"], w«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs wabs),           schemas: [w«rya».properties["wabs"], w«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs wptr),           schemas: [w«rya».properties["wptr"], w«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs y),              schemas: [w«rya».properties["y"], y«w«rya»»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs x),              schemas: [w«rya».properties["x"], x«w«rya»»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs z),              schemas: [w«rya».properties["z"], y«w«rya»»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(wabs y wabs),         schemas: [y«w«rya»».properties["wabs"], w«rya»],                                                                                        line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr),         schemas: [y«w«rya»».properties["wptr"], y«w«rya»»["$defs"]["z"]["$defs"]["w"]],                                                         line: __LINE__},
        {ind: rya, ptr: %w(wabs y yabs),         schemas: [y«w«rya»».properties["yabs"], y«w«rya»»],                                                                                     line: __LINE__},
        {ind: rya, ptr: %w(wabs y yptr),         schemas: [y«w«rya»».properties["yptr"], y«w«rya»»],                                                                                     line: __LINE__},
        {ind: rya, ptr: %w(wabs y x),            schemas: [y«w«rya»».properties["x"], x«w«rya»»],                                                                                        line: __LINE__},
        {ind: rya, ptr: %w(wabs y zabsptr),      schemas: [y«w«rya»».properties["zabsptr"], y«w«rya»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rya, ptr: %w(wabs y zptr),         schemas: [y«w«rya»».properties["zptr"], y«w«rya»»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rya, ptr: %w(wabs x wabs),         schemas: [x«w«rya»».properties["wabs"], w«rya»],                                                                                        line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr),         schemas: [x«w«rya»».properties["wptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs x yabs),         schemas: [x«w«rya»».properties["yabs"], y«w«rya»»],                                                                                     line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr),         schemas: [x«w«rya»».properties["yptr"], x«w«rya»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rya, ptr: %w(wabs x xabs),         schemas: [x«w«rya»».properties["xabs"], x«w«rya»»],                                                                                     line: __LINE__},
        {ind: rya, ptr: %w(wabs x xptr),         schemas: [x«w«rya»».properties["xptr"], x«w«rya»»],                                                                                     line: __LINE__},
        {ind: rya, ptr: %w(wabs x zabsptr),      schemas: [x«w«rya»».properties["zabsptr"], y«w«rya»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr),         schemas: [x«w«rya»».properties["zptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rya, ptr: %w(wabs z wabs),         schemas: [y«w«rya»»["$defs"]["z"].properties["wabs"], w«rya»],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(wabs z wptr),         schemas: [y«w«rya»»["$defs"]["z"].properties["wptr"], y«w«rya»»["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs z yabs),         schemas: [y«w«rya»»["$defs"]["z"].properties["yabs"], y«w«rya»»],                                                                       line: __LINE__},
        {ind: rya, ptr: %w(wabs z yptr),         schemas: [y«w«rya»»["$defs"]["z"].properties["yptr"], y«w«rya»»],                                                                       line: __LINE__},
        {ind: rya, ptr: %w(wabs z x),            schemas: [y«w«rya»»["$defs"]["z"].properties["x"], x«w«rya»»],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(wabs z zabsptr),      schemas: [y«w«rya»»["$defs"]["z"].properties["zabsptr"], y«w«rya»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rya, ptr: %w(wabs z zptr),         schemas: [y«w«rya»»["$defs"]["z"].properties["zptr"], y«w«rya»»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr wabs),    schemas: [y«w«rya»»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rya»],                                                            line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr wptr),    schemas: [y«w«rya»»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«w«rya»»["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr y),       schemas: [y«w«rya»»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rya»»],                                                            line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr x),       schemas: [y«w«rya»»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rya»»],                                                            line: __LINE__},
        {ind: rya, ptr: %w(wabs y wptr z),       schemas: [y«w«rya»»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rya»»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr wabs),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rya»],                                              line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr wptr),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]], line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr y),       schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rya»»],                                              line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr x),       schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rya»»],                                              line: __LINE__},
        {ind: rya, ptr: %w(wabs x wptr z),       schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rya»»["$defs"]["z"]],                                line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr wabs),    schemas: [x«w«rya»»["$defs"]["y"].properties["wabs"], w«rya»],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr wptr),    schemas: [x«w«rya»»["$defs"]["y"].properties["wptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr yabs),    schemas: [x«w«rya»»["$defs"]["y"].properties["yabs"], y«w«rya»»],                                                                       line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr yptr),    schemas: [x«w«rya»»["$defs"]["y"].properties["yptr"], x«w«rya»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr x),       schemas: [x«w«rya»»["$defs"]["y"].properties["x"], x«w«rya»»],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr zabsptr), schemas: [x«w«rya»»["$defs"]["y"].properties["zabsptr"], y«w«rya»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rya, ptr: %w(wabs x yptr zptr),    schemas: [x«w«rya»»["$defs"]["y"].properties["zptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr wabs),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rya»],                                                            line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr wptr),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],               line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr yabs),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w«rya»»],                                                         line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr yptr),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w«rya»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr x),       schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«w«rya»»],                                                            line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr zabsptr), schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w«rya»»["$defs"]["z"]],                                        line: __LINE__},
        {ind: rya, ptr: %w(wabs x zptr zptr),    schemas: [x«w«rya»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w«rya»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},
        {ind: rya, ptr: %w(wptr),                schemas: [y«rya».properties["wptr"], y«rya»["$defs"]["z"]["$defs"]["w"]],                                                               line: __LINE__},
        {ind: rya, ptr: %w(wptr wabs),           schemas: [y«rya»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rya»],                                                               line: __LINE__},
        {ind: rya, ptr: %w(wptr wptr),           schemas: [y«rya»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rya»["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rya, ptr: %w(wptr y),              schemas: [y«rya»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rya»»],                                                               line: __LINE__},
        {ind: rya, ptr: %w(wptr x),              schemas: [y«rya»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rya»»],                                                               line: __LINE__},
        {ind: rya, ptr: %w(wptr z),              schemas: [y«rya»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rya»»["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rya, ptr: %w(yabs),                schemas: [y«rya».properties["yabs"], y«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(yptr),                schemas: [y«rya».properties["yptr"], y«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(x),                   schemas: [y«rya».properties["x"], x«rya»],                                                                                              line: __LINE__},
        {ind: rya, ptr: %w(zabsptr),             schemas: [y«rya».properties["zabsptr"], y«rya»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(zptr),                schemas: [y«rya».properties["zptr"], y«rya»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(x wabs),              schemas: [x«rya».properties["wabs"], w«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(x wptr),              schemas: [x«rya».properties["wptr"], x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x yabs),              schemas: [x«rya».properties["yabs"], y«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(x yptr),              schemas: [x«rya».properties["yptr"], x«rya»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(x xabs),              schemas: [x«rya».properties["xabs"], x«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(x xptr),              schemas: [x«rya».properties["xptr"], x«rya»],                                                                                           line: __LINE__},
        {ind: rya, ptr: %w(x zabsptr),           schemas: [x«rya».properties["zabsptr"], y«rya»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rya, ptr: %w(x zptr),              schemas: [x«rya».properties["zptr"], x«rya»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rya, ptr: %w(zabsptr wabs),        schemas: [y«rya»["$defs"]["z"].properties["wabs"], w«rya»],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(zabsptr wptr),        schemas: [y«rya»["$defs"]["z"].properties["wptr"], y«rya»["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rya, ptr: %w(zabsptr yabs),        schemas: [y«rya»["$defs"]["z"].properties["yabs"], y«rya»],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(zabsptr yptr),        schemas: [y«rya»["$defs"]["z"].properties["yptr"], y«rya»],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(zabsptr x),           schemas: [y«rya»["$defs"]["z"].properties["x"], x«rya»],                                                                                line: __LINE__},
        {ind: rya, ptr: %w(zabsptr zabsptr),     schemas: [y«rya»["$defs"]["z"].properties["zabsptr"], y«rya»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rya, ptr: %w(zabsptr zptr),        schemas: [y«rya»["$defs"]["z"].properties["zptr"], y«rya»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rya, ptr: %w(x wptr wabs),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rya»],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x wptr wptr),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: rya, ptr: %w(x wptr y),            schemas: [x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rya»»],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x wptr x),            schemas: [x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rya»»],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x wptr z),            schemas: [x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rya»»["$defs"]["z"]],                                   line: __LINE__},
        {ind: rya, ptr: %w(x yptr wabs),         schemas: [x«rya»["$defs"]["y"].properties["wabs"], w«rya»],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(x yptr wptr),         schemas: [x«rya»["$defs"]["y"].properties["wptr"], x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rya, ptr: %w(x yptr yabs),         schemas: [x«rya»["$defs"]["y"].properties["yabs"], y«rya»],                                                                             line: __LINE__},
        {ind: rya, ptr: %w(x yptr yptr),         schemas: [x«rya»["$defs"]["y"].properties["yptr"], x«rya»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: rya, ptr: %w(x yptr x),            schemas: [x«rya»["$defs"]["y"].properties["x"], x«rya»],                                                                                line: __LINE__},
        {ind: rya, ptr: %w(x yptr zabsptr),      schemas: [x«rya»["$defs"]["y"].properties["zabsptr"], y«rya»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rya, ptr: %w(x yptr zptr),         schemas: [x«rya»["$defs"]["y"].properties["zptr"], x«rya»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x zptr wabs),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rya»],                                                               line: __LINE__},
        {ind: rya, ptr: %w(x zptr wptr),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rya»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                     line: __LINE__},
        {ind: rya, ptr: %w(x zptr yabs),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rya»],                                                               line: __LINE__},
        {ind: rya, ptr: %w(x zptr yptr),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rya»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: rya, ptr: %w(x zptr x),            schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rya»],                                                                  line: __LINE__},
        {ind: rya, ptr: %w(x zptr zabsptr),      schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rya»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rya, ptr: %w(x zptr zptr),         schemas: [x«rya»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rya»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},

        {ind: ryb, ptr: %w(),                schemas: [ryb, y«ryb»],                                                                                                                 line: __LINE__},
        {ind: ryb, ptr: %w(wabs),            schemas: [y«ryb».properties["wabs"], w«y«ryb»»],                                                                                        line: __LINE__},
        {ind: ryb, ptr: %w(wabs wabs),       schemas: [w«y«ryb»».properties["wabs"], w«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(wabs wptr),       schemas: [w«y«ryb»».properties["wptr"], w«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(wabs y),          schemas: [w«y«ryb»».properties["y"], y«ryb»],                                                                                           line: __LINE__},
        {ind: ryb, ptr: %w(wabs x),          schemas: [w«y«ryb»».properties["x"], x«y«ryb»»],                                                                                        line: __LINE__},
        {ind: ryb, ptr: %w(wabs z),          schemas: [w«y«ryb»».properties["z"], y«ryb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: ryb, ptr: %w(wptr),            schemas: [y«ryb».properties["wptr"], w«y«ryb»»],                                                                                        line: __LINE__},
        {ind: ryb, ptr: %w(yabs),            schemas: [y«ryb».properties["yabs"], y«ryb»],                                                                                           line: __LINE__},
        {ind: ryb, ptr: %w(yptr),            schemas: [y«ryb».properties["yptr"], y«ryb»],                                                                                           line: __LINE__},
        {ind: ryb, ptr: %w(x),               schemas: [y«ryb».properties["x"], x«y«ryb»»],                                                                                           line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr),         schemas: [y«ryb».properties["zabsptr"], y«ryb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: ryb, ptr: %w(zptr),            schemas: [y«ryb».properties["zptr"], y«ryb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: ryb, ptr: %w(x wabs),          schemas: [x«y«ryb»».properties["wabs"], w«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(x wptr),          schemas: [x«y«ryb»».properties["wptr"], w«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(x yabs),          schemas: [x«y«ryb»».properties["yabs"], y«ryb»],                                                                                        line: __LINE__},
        {ind: ryb, ptr: %w(x yptr),          schemas: [x«y«ryb»».properties["yptr"], x«y«ryb»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: ryb, ptr: %w(x xabs),          schemas: [x«y«ryb»».properties["xabs"], x«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(x xptr),          schemas: [x«y«ryb»».properties["xptr"], x«y«ryb»»],                                                                                     line: __LINE__},
        {ind: ryb, ptr: %w(x zabsptr),       schemas: [x«y«ryb»».properties["zabsptr"], y«ryb»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: ryb, ptr: %w(x zptr),          schemas: [x«y«ryb»».properties["zptr"], x«y«ryb»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr wabs),    schemas: [y«ryb»["$defs"]["z"].properties["wabs"], w«y«ryb»»],                                                                          line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr wptr),    schemas: [y«ryb»["$defs"]["z"].properties["wptr"], w«y«ryb»»],                                                                          line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr yabs),    schemas: [y«ryb»["$defs"]["z"].properties["yabs"], y«ryb»],                                                                             line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr yptr),    schemas: [y«ryb»["$defs"]["z"].properties["yptr"], y«ryb»],                                                                             line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr x),       schemas: [y«ryb»["$defs"]["z"].properties["x"], x«y«ryb»»],                                                                             line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr zabsptr), schemas: [y«ryb»["$defs"]["z"].properties["zabsptr"], y«ryb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: ryb, ptr: %w(zabsptr zptr),    schemas: [y«ryb»["$defs"]["z"].properties["zptr"], y«ryb»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: ryb, ptr: %w(x yptr wabs),     schemas: [x«y«ryb»»["$defs"]["y"].properties["wabs"], w«y«ryb»»],                                                                       line: __LINE__},
        {ind: ryb, ptr: %w(x yptr wptr),     schemas: [x«y«ryb»»["$defs"]["y"].properties["wptr"], w«y«ryb»»],                                                                       line: __LINE__},
        {ind: ryb, ptr: %w(x yptr yabs),     schemas: [x«y«ryb»»["$defs"]["y"].properties["yabs"], y«ryb»],                                                                          line: __LINE__},
        {ind: ryb, ptr: %w(x yptr yptr),     schemas: [x«y«ryb»»["$defs"]["y"].properties["yptr"], x«y«ryb»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: ryb, ptr: %w(x yptr x),        schemas: [x«y«ryb»»["$defs"]["y"].properties["x"], x«y«ryb»»],                                                                          line: __LINE__},
        {ind: ryb, ptr: %w(x yptr zabsptr),  schemas: [x«y«ryb»»["$defs"]["y"].properties["zabsptr"], y«ryb»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: ryb, ptr: %w(x yptr zptr),     schemas: [x«y«ryb»»["$defs"]["y"].properties["zptr"], x«y«ryb»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: ryb, ptr: %w(x zptr wabs),     schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«ryb»»],                                                         line: __LINE__},
        {ind: ryb, ptr: %w(x zptr wptr),     schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«ryb»»],                                                         line: __LINE__},
        {ind: ryb, ptr: %w(x zptr yabs),     schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«ryb»],                                                            line: __LINE__},
        {ind: ryb, ptr: %w(x zptr yptr),     schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«ryb»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: ryb, ptr: %w(x zptr x),        schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«ryb»»],                                                            line: __LINE__},
        {ind: ryb, ptr: %w(x zptr zabsptr),  schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«ryb»["$defs"]["z"]],                                           line: __LINE__},
        {ind: ryb, ptr: %w(x zptr zptr),     schemas: [x«y«ryb»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«ryb»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: ryab, ptr: %w(),                schemas: [ryab, y«ryab»],                                                                                                               line: __LINE__},
        {ind: ryab, ptr: %w(wabs),            schemas: [y«ryab».properties["wabs"], w«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(wabs wabs),       schemas: [w«ryab».properties["wabs"], w«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(wabs wptr),       schemas: [w«ryab».properties["wptr"], w«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(wabs y),          schemas: [w«ryab».properties["y"], y«ryab»],                                                                                            line: __LINE__},
        {ind: ryab, ptr: %w(wabs x),          schemas: [w«ryab».properties["x"], x«ryab»],                                                                                            line: __LINE__},
        {ind: ryab, ptr: %w(wabs z),          schemas: [w«ryab».properties["z"], y«ryab»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: ryab, ptr: %w(wptr),            schemas: [y«ryab».properties["wptr"], y«ryab»["$defs"]["z"]["$defs"]["w"]],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(yabs),            schemas: [y«ryab».properties["yabs"], y«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(yptr),            schemas: [y«ryab».properties["yptr"], y«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(x),               schemas: [y«ryab».properties["x"], x«ryab»],                                                                                            line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr),         schemas: [y«ryab».properties["zabsptr"], y«ryab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: ryab, ptr: %w(zptr),            schemas: [y«ryab».properties["zptr"], y«ryab»["$defs"]["z"]],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(x wabs),          schemas: [x«ryab».properties["wabs"], w«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(x wptr),          schemas: [x«ryab».properties["wptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: ryab, ptr: %w(x yabs),          schemas: [x«ryab».properties["yabs"], y«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(x yptr),          schemas: [x«ryab».properties["yptr"], x«ryab»["$defs"]["y"]],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(x xabs),          schemas: [x«ryab».properties["xabs"], x«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(x xptr),          schemas: [x«ryab».properties["xptr"], x«ryab»],                                                                                         line: __LINE__},
        {ind: ryab, ptr: %w(x zabsptr),       schemas: [x«ryab».properties["zabsptr"], y«ryab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: ryab, ptr: %w(x zptr),          schemas: [x«ryab».properties["zptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr wabs),    schemas: [y«ryab»["$defs"]["z"].properties["wabs"], w«ryab»],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr wptr),    schemas: [y«ryab»["$defs"]["z"].properties["wptr"], y«ryab»["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr yabs),    schemas: [y«ryab»["$defs"]["z"].properties["yabs"], y«ryab»],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr yptr),    schemas: [y«ryab»["$defs"]["z"].properties["yptr"], y«ryab»],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr x),       schemas: [y«ryab»["$defs"]["z"].properties["x"], x«ryab»],                                                                              line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr zabsptr), schemas: [y«ryab»["$defs"]["z"].properties["zabsptr"], y«ryab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: ryab, ptr: %w(zabsptr zptr),    schemas: [y«ryab»["$defs"]["z"].properties["zptr"], y«ryab»["$defs"]["z"]],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(wptr wabs),       schemas: [y«ryab»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«ryab»],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(wptr wptr),       schemas: [y«ryab»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«ryab»["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: ryab, ptr: %w(wptr y),          schemas: [y«ryab»["$defs"]["z"]["$defs"]["w"].properties["y"], y«ryab»],                                                                line: __LINE__},
        {ind: ryab, ptr: %w(wptr x),          schemas: [y«ryab»["$defs"]["z"]["$defs"]["w"].properties["x"], x«ryab»],                                                                line: __LINE__},
        {ind: ryab, ptr: %w(wptr z),          schemas: [y«ryab»["$defs"]["z"]["$defs"]["w"].properties["z"], y«ryab»["$defs"]["z"]],                                                  line: __LINE__},
        {ind: ryab, ptr: %w(x wptr wabs),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«ryab»],                                               line: __LINE__},
        {ind: ryab, ptr: %w(x wptr wptr),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],     line: __LINE__},
        {ind: ryab, ptr: %w(x wptr y),        schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«ryab»],                                                  line: __LINE__},
        {ind: ryab, ptr: %w(x wptr x),        schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«ryab»],                                                  line: __LINE__},
        {ind: ryab, ptr: %w(x wptr z),        schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«ryab»["$defs"]["z"]],                                    line: __LINE__},
        {ind: ryab, ptr: %w(x yptr wabs),     schemas: [x«ryab»["$defs"]["y"].properties["wabs"], w«ryab»],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(x yptr wptr),     schemas: [x«ryab»["$defs"]["y"].properties["wptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: ryab, ptr: %w(x yptr yabs),     schemas: [x«ryab»["$defs"]["y"].properties["yabs"], y«ryab»],                                                                           line: __LINE__},
        {ind: ryab, ptr: %w(x yptr yptr),     schemas: [x«ryab»["$defs"]["y"].properties["yptr"], x«ryab»["$defs"]["y"]],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(x yptr x),        schemas: [x«ryab»["$defs"]["y"].properties["x"], x«ryab»],                                                                              line: __LINE__},
        {ind: ryab, ptr: %w(x yptr zabsptr),  schemas: [x«ryab»["$defs"]["y"].properties["zabsptr"], y«ryab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: ryab, ptr: %w(x yptr zptr),     schemas: [x«ryab»["$defs"]["y"].properties["zptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]],                                               line: __LINE__},
        {ind: ryab, ptr: %w(x zptr wabs),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«ryab»],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(x zptr wptr),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                   line: __LINE__},
        {ind: ryab, ptr: %w(x zptr yabs),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«ryab»],                                                             line: __LINE__},
        {ind: ryab, ptr: %w(x zptr yptr),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«ryab»["$defs"]["y"]],                                               line: __LINE__},
        {ind: ryab, ptr: %w(x zptr x),        schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["x"], x«ryab»],                                                                line: __LINE__},
        {ind: ryab, ptr: %w(x zptr zabsptr),  schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«ryab»["$defs"]["z"]],                                            line: __LINE__},
        {ind: ryab, ptr: %w(x zptr zptr),     schemas: [x«ryab»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«ryab»["$defs"]["y"]["$defs"]["z"]],                                 line: __LINE__},

        {ind: z, ptr: %w(),                      schemas: [z],                                                                                                                       line: __LINE__},
        {ind: z, ptr: %w(wabs),                  schemas: [z.properties["wabs"], w«y»],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(wabs wabs),             schemas: [w«y».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs wptr),             schemas: [w«y».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y),                schemas: [w«y».properties["y"], y«w»],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(wabs x),                schemas: [w«y».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs z),                schemas: [w«y».properties["z"], y«w»["$defs"]["z"]],                                                                                line: __LINE__},
        {ind: z, ptr: %w(wabs y wabs),           schemas: [y«w».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y wptr),           schemas: [y«w».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y yabs),           schemas: [y«w».properties["yabs"], y«w»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y yptr),           schemas: [y«w».properties["yptr"], y«w»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y x),              schemas: [y«w».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(wabs y zabsptr),        schemas: [y«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: z, ptr: %w(wabs y zptr),           schemas: [y«w».properties["zptr"], y«w»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs x wabs),           schemas: [x«y«w»».properties["wabs"], w«y»],                                                                                        line: __LINE__},
        {ind: z, ptr: %w(wabs x wptr),           schemas: [x«y«w»».properties["wptr"], w«y»],                                                                                        line: __LINE__},
        {ind: z, ptr: %w(wabs x yabs),           schemas: [x«y«w»».properties["yabs"], y«w»],                                                                                        line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr),           schemas: [x«y«w»».properties["yptr"], x«y«w»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: z, ptr: %w(wabs x xabs),           schemas: [x«y«w»».properties["xabs"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: z, ptr: %w(wabs x xptr),           schemas: [x«y«w»».properties["xptr"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: z, ptr: %w(wabs x zabsptr),        schemas: [x«y«w»».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr),           schemas: [x«y«w»».properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: z, ptr: %w(wabs z wabs),           schemas: [y«w»["$defs"]["z"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs z wptr),           schemas: [y«w»["$defs"]["z"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs z yabs),           schemas: [y«w»["$defs"]["z"].properties["yabs"], y«w»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs z yptr),           schemas: [y«w»["$defs"]["z"].properties["yptr"], y«w»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs z x),              schemas: [y«w»["$defs"]["z"].properties["x"], x«y«w»»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(wabs z zabsptr),        schemas: [y«w»["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: z, ptr: %w(wabs z zptr),           schemas: [y«w»["$defs"]["z"].properties["zptr"], y«w»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr wabs),      schemas: [x«y«w»»["$defs"]["y"].properties["wabs"], w«y»],                                                                          line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr wptr),      schemas: [x«y«w»»["$defs"]["y"].properties["wptr"], w«y»],                                                                          line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr yabs),      schemas: [x«y«w»»["$defs"]["y"].properties["yabs"], y«w»],                                                                          line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr yptr),      schemas: [x«y«w»»["$defs"]["y"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr x),         schemas: [x«y«w»»["$defs"]["y"].properties["x"], x«y«w»»],                                                                          line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr zabsptr),   schemas: [x«y«w»»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: z, ptr: %w(wabs x yptr zptr),      schemas: [x«y«w»»["$defs"]["y"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr wabs),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                            line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr wptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                            line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr yabs),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                            line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr yptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr x),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                            line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr zabsptr),   schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                           line: __LINE__},
        {ind: z, ptr: %w(wabs x zptr zptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},
        {ind: z, ptr: %w(wptr),                  schemas: [z.properties["wptr"], w«y»],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(yabs),                  schemas: [z.properties["yabs"], y],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(yabs wabs),             schemas: [y.properties["wabs"], w«y»],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(yabs wptr),             schemas: [y.properties["wptr"], w«y»],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(yabs yabs),             schemas: [y.properties["yabs"], y],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(yabs yptr),             schemas: [y.properties["yptr"], y],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(yabs x),                schemas: [y.properties["x"], x«y»],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(yabs zabsptr),          schemas: [y.properties["zabsptr"], z],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(yabs zptr),             schemas: [y.properties["zptr"], z],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(x wabs),                schemas: [x«y».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(x wptr),                schemas: [x«y».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(x yabs),                schemas: [x«y».properties["yabs"], y],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(x yptr),                schemas: [x«y».properties["yptr"], x«y»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: z, ptr: %w(x xabs),                schemas: [x«y».properties["xabs"], x«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(x xptr),                schemas: [x«y».properties["xptr"], x«y»],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(x zabsptr),             schemas: [x«y».properties["zabsptr"], z],                                                                                           line: __LINE__},
        {ind: z, ptr: %w(x zptr),                schemas: [x«y».properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: z, ptr: %w(yptr),                  schemas: [z.properties["yptr"], y],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(x),                     schemas: [z.properties["x"], x«y»],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(zabsptr),               schemas: [z.properties["zabsptr"], z],                                                                                              line: __LINE__},
        {ind: z, ptr: %w(zptr),                  schemas: [z.properties["zptr"], z],                                                                                                 line: __LINE__},
        {ind: z, ptr: %w(x yptr wabs),           schemas: [x«y»["$defs"]["y"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(x yptr wptr),           schemas: [x«y»["$defs"]["y"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: z, ptr: %w(x yptr yabs),           schemas: [x«y»["$defs"]["y"].properties["yabs"], y],                                                                                line: __LINE__},
        {ind: z, ptr: %w(x yptr yptr),           schemas: [x«y»["$defs"]["y"].properties["yptr"], x«y»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: z, ptr: %w(x yptr x),              schemas: [x«y»["$defs"]["y"].properties["x"], x«y»],                                                                                line: __LINE__},
        {ind: z, ptr: %w(x yptr zabsptr),        schemas: [x«y»["$defs"]["y"].properties["zabsptr"], z],                                                                             line: __LINE__},
        {ind: z, ptr: %w(x yptr zptr),           schemas: [x«y»["$defs"]["y"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: z, ptr: %w(x zptr wabs),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                               line: __LINE__},
        {ind: z, ptr: %w(x zptr wptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                               line: __LINE__},
        {ind: z, ptr: %w(x zptr yabs),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y],                                                                  line: __LINE__},
        {ind: z, ptr: %w(x zptr yptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: z, ptr: %w(x zptr x),              schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y»],                                                                  line: __LINE__},
        {ind: z, ptr: %w(x zptr zabsptr),        schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], z],                                                               line: __LINE__},
        {ind: z, ptr: %w(x zptr zptr),           schemas: [x«y»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},

        {ind: rza, ptr: %w(),                    schemas: [rza, y«rza»["$defs"]["z"]],                                                                                                   line: __LINE__},
        {ind: rza, ptr: %w(wabs),                schemas: [y«rza»["$defs"]["z"].properties["wabs"], w«rza»],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(wabs wabs),           schemas: [w«rza».properties["wabs"], w«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs wptr),           schemas: [w«rza».properties["wptr"], w«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs y),              schemas: [w«rza».properties["y"], y«w«rza»»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs x),              schemas: [w«rza».properties["x"], x«w«rza»»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs z),              schemas: [w«rza».properties["z"], y«w«rza»»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(wabs y wabs),         schemas: [y«w«rza»».properties["wabs"], w«rza»],                                                                                        line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr),         schemas: [y«w«rza»».properties["wptr"], y«w«rza»»["$defs"]["z"]["$defs"]["w"]],                                                         line: __LINE__},
        {ind: rza, ptr: %w(wabs y yabs),         schemas: [y«w«rza»».properties["yabs"], y«w«rza»»],                                                                                     line: __LINE__},
        {ind: rza, ptr: %w(wabs y yptr),         schemas: [y«w«rza»».properties["yptr"], y«w«rza»»],                                                                                     line: __LINE__},
        {ind: rza, ptr: %w(wabs y x),            schemas: [y«w«rza»».properties["x"], x«w«rza»»],                                                                                        line: __LINE__},
        {ind: rza, ptr: %w(wabs y zabsptr),      schemas: [y«w«rza»».properties["zabsptr"], y«w«rza»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rza, ptr: %w(wabs y zptr),         schemas: [y«w«rza»».properties["zptr"], y«w«rza»»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rza, ptr: %w(wabs x wabs),         schemas: [x«w«rza»».properties["wabs"], w«rza»],                                                                                        line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr),         schemas: [x«w«rza»».properties["wptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs x yabs),         schemas: [x«w«rza»».properties["yabs"], y«w«rza»»],                                                                                     line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr),         schemas: [x«w«rza»».properties["yptr"], x«w«rza»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rza, ptr: %w(wabs x xabs),         schemas: [x«w«rza»».properties["xabs"], x«w«rza»»],                                                                                     line: __LINE__},
        {ind: rza, ptr: %w(wabs x xptr),         schemas: [x«w«rza»».properties["xptr"], x«w«rza»»],                                                                                     line: __LINE__},
        {ind: rza, ptr: %w(wabs x zabsptr),      schemas: [x«w«rza»».properties["zabsptr"], y«w«rza»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr),         schemas: [x«w«rza»».properties["zptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rza, ptr: %w(wabs z wabs),         schemas: [y«w«rza»»["$defs"]["z"].properties["wabs"], w«rza»],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(wabs z wptr),         schemas: [y«w«rza»»["$defs"]["z"].properties["wptr"], y«w«rza»»["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs z yabs),         schemas: [y«w«rza»»["$defs"]["z"].properties["yabs"], y«w«rza»»],                                                                       line: __LINE__},
        {ind: rza, ptr: %w(wabs z yptr),         schemas: [y«w«rza»»["$defs"]["z"].properties["yptr"], y«w«rza»»],                                                                       line: __LINE__},
        {ind: rza, ptr: %w(wabs z x),            schemas: [y«w«rza»»["$defs"]["z"].properties["x"], x«w«rza»»],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(wabs z zabsptr),      schemas: [y«w«rza»»["$defs"]["z"].properties["zabsptr"], y«w«rza»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rza, ptr: %w(wabs z zptr),         schemas: [y«w«rza»»["$defs"]["z"].properties["zptr"], y«w«rza»»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr wabs),    schemas: [y«w«rza»»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rza»],                                                            line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr wptr),    schemas: [y«w«rza»»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«w«rza»»["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr y),       schemas: [y«w«rza»»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rza»»],                                                            line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr x),       schemas: [y«w«rza»»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rza»»],                                                            line: __LINE__},
        {ind: rza, ptr: %w(wabs y wptr z),       schemas: [y«w«rza»»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rza»»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr wabs),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rza»],                                              line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr wptr),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]], line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr y),       schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rza»»],                                              line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr x),       schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rza»»],                                              line: __LINE__},
        {ind: rza, ptr: %w(wabs x wptr z),       schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rza»»["$defs"]["z"]],                                line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr wabs),    schemas: [x«w«rza»»["$defs"]["y"].properties["wabs"], w«rza»],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr wptr),    schemas: [x«w«rza»»["$defs"]["y"].properties["wptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr yabs),    schemas: [x«w«rza»»["$defs"]["y"].properties["yabs"], y«w«rza»»],                                                                       line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr yptr),    schemas: [x«w«rza»»["$defs"]["y"].properties["yptr"], x«w«rza»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr x),       schemas: [x«w«rza»»["$defs"]["y"].properties["x"], x«w«rza»»],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr zabsptr), schemas: [x«w«rza»»["$defs"]["y"].properties["zabsptr"], y«w«rza»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rza, ptr: %w(wabs x yptr zptr),    schemas: [x«w«rza»»["$defs"]["y"].properties["zptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr wabs),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rza»],                                                            line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr wptr),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],               line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr yabs),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w«rza»»],                                                         line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr yptr),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w«rza»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr x),       schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«w«rza»»],                                                            line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr zabsptr), schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w«rza»»["$defs"]["z"]],                                        line: __LINE__},
        {ind: rza, ptr: %w(wabs x zptr zptr),    schemas: [x«w«rza»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w«rza»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},
        {ind: rza, ptr: %w(wptr),                schemas: [y«rza»["$defs"]["z"].properties["wptr"], y«rza»["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rza, ptr: %w(wptr wabs),           schemas: [y«rza»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rza»],                                                               line: __LINE__},
        {ind: rza, ptr: %w(wptr wptr),           schemas: [y«rza»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rza»["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rza, ptr: %w(wptr y),              schemas: [y«rza»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rza»»],                                                               line: __LINE__},
        {ind: rza, ptr: %w(wptr x),              schemas: [y«rza»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rza»»],                                                               line: __LINE__},
        {ind: rza, ptr: %w(wptr z),              schemas: [y«rza»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rza»»["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rza, ptr: %w(yabs),                schemas: [y«rza»["$defs"]["z"].properties["yabs"], y«rza»],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(yabs wabs),           schemas: [y«rza».properties["wabs"], w«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(yabs wptr),           schemas: [y«rza».properties["wptr"], y«rza»["$defs"]["z"]["$defs"]["w"]],                                                               line: __LINE__},
        {ind: rza, ptr: %w(yabs yabs),           schemas: [y«rza».properties["yabs"], y«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(yabs yptr),           schemas: [y«rza».properties["yptr"], y«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(yabs x),              schemas: [y«rza».properties["x"], x«rza»],                                                                                              line: __LINE__},
        {ind: rza, ptr: %w(yabs zabsptr),        schemas: [y«rza».properties["zabsptr"], y«rza»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(yabs zptr),           schemas: [y«rza».properties["zptr"], y«rza»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(x wabs),              schemas: [x«rza».properties["wabs"], w«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(x wptr),              schemas: [x«rza».properties["wptr"], x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x yabs),              schemas: [x«rza».properties["yabs"], y«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(x yptr),              schemas: [x«rza».properties["yptr"], x«rza»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(x xabs),              schemas: [x«rza».properties["xabs"], x«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(x xptr),              schemas: [x«rza».properties["xptr"], x«rza»],                                                                                           line: __LINE__},
        {ind: rza, ptr: %w(x zabsptr),           schemas: [x«rza».properties["zabsptr"], y«rza»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rza, ptr: %w(x zptr),              schemas: [x«rza».properties["zptr"], x«rza»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rza, ptr: %w(yptr),                schemas: [y«rza»["$defs"]["z"].properties["yptr"], y«rza»],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(x),                   schemas: [y«rza»["$defs"]["z"].properties["x"], x«rza»],                                                                                line: __LINE__},
        {ind: rza, ptr: %w(zabsptr),             schemas: [y«rza»["$defs"]["z"].properties["zabsptr"], y«rza»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rza, ptr: %w(zptr),                schemas: [y«rza»["$defs"]["z"].properties["zptr"], y«rza»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rza, ptr: %w(x wptr wabs),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rza»],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x wptr wptr),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: rza, ptr: %w(x wptr y),            schemas: [x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rza»»],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x wptr x),            schemas: [x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rza»»],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x wptr z),            schemas: [x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rza»»["$defs"]["z"]],                                   line: __LINE__},
        {ind: rza, ptr: %w(x yptr wabs),         schemas: [x«rza»["$defs"]["y"].properties["wabs"], w«rza»],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(x yptr wptr),         schemas: [x«rza»["$defs"]["y"].properties["wptr"], x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                   line: __LINE__},
        {ind: rza, ptr: %w(x yptr yabs),         schemas: [x«rza»["$defs"]["y"].properties["yabs"], y«rza»],                                                                             line: __LINE__},
        {ind: rza, ptr: %w(x yptr yptr),         schemas: [x«rza»["$defs"]["y"].properties["yptr"], x«rza»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: rza, ptr: %w(x yptr x),            schemas: [x«rza»["$defs"]["y"].properties["x"], x«rza»],                                                                                line: __LINE__},
        {ind: rza, ptr: %w(x yptr zabsptr),      schemas: [x«rza»["$defs"]["y"].properties["zabsptr"], y«rza»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rza, ptr: %w(x yptr zptr),         schemas: [x«rza»["$defs"]["y"].properties["zptr"], x«rza»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x zptr wabs),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rza»],                                                               line: __LINE__},
        {ind: rza, ptr: %w(x zptr wptr),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rza»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                     line: __LINE__},
        {ind: rza, ptr: %w(x zptr yabs),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rza»],                                                               line: __LINE__},
        {ind: rza, ptr: %w(x zptr yptr),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rza»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: rza, ptr: %w(x zptr x),            schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rza»],                                                                  line: __LINE__},
        {ind: rza, ptr: %w(x zptr zabsptr),      schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rza»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rza, ptr: %w(x zptr zptr),         schemas: [x«rza»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rza»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},

        {ind: rzb, ptr: %w(),               schemas: [rzb, y«rzb»["$defs"]["z"]],                                                                                                   line: __LINE__},
        {ind: rzb, ptr: %w(wabs),           schemas: [y«rzb»["$defs"]["z"].properties["wabs"], w«y«rzb»»],                                                                          line: __LINE__},
        {ind: rzb, ptr: %w(wabs wabs),      schemas: [w«y«rzb»».properties["wabs"], w«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(wabs wptr),      schemas: [w«y«rzb»».properties["wptr"], w«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(wabs y),         schemas: [w«y«rzb»».properties["y"], y«rzb»],                                                                                           line: __LINE__},
        {ind: rzb, ptr: %w(wabs x),         schemas: [w«y«rzb»».properties["x"], x«y«rzb»»],                                                                                        line: __LINE__},
        {ind: rzb, ptr: %w(wabs z),         schemas: [w«y«rzb»».properties["z"], y«rzb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rzb, ptr: %w(yabs wabs),      schemas: [y«rzb».properties["wabs"], w«y«rzb»»],                                                                                        line: __LINE__},
        {ind: rzb, ptr: %w(yabs wptr),      schemas: [y«rzb».properties["wptr"], w«y«rzb»»],                                                                                        line: __LINE__},
        {ind: rzb, ptr: %w(yabs yabs),      schemas: [y«rzb».properties["yabs"], y«rzb»],                                                                                           line: __LINE__},
        {ind: rzb, ptr: %w(yabs yptr),      schemas: [y«rzb».properties["yptr"], y«rzb»],                                                                                           line: __LINE__},
        {ind: rzb, ptr: %w(yabs x),         schemas: [y«rzb».properties["x"], x«y«rzb»»],                                                                                           line: __LINE__},
        {ind: rzb, ptr: %w(yabs zabsptr),   schemas: [y«rzb».properties["zabsptr"], y«rzb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rzb, ptr: %w(yabs zptr),      schemas: [y«rzb».properties["zptr"], y«rzb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rzb, ptr: %w(x wabs),         schemas: [x«y«rzb»».properties["wabs"], w«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(x wptr),         schemas: [x«y«rzb»».properties["wptr"], w«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(x yabs),         schemas: [x«y«rzb»».properties["yabs"], y«rzb»],                                                                                        line: __LINE__},
        {ind: rzb, ptr: %w(x yptr),         schemas: [x«y«rzb»».properties["yptr"], x«y«rzb»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rzb, ptr: %w(x xabs),         schemas: [x«y«rzb»».properties["xabs"], x«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(x xptr),         schemas: [x«y«rzb»».properties["xptr"], x«y«rzb»»],                                                                                     line: __LINE__},
        {ind: rzb, ptr: %w(x zabsptr),      schemas: [x«y«rzb»».properties["zabsptr"], y«rzb»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rzb, ptr: %w(x zptr),         schemas: [x«y«rzb»».properties["zptr"], x«y«rzb»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rzb, ptr: %w(wptr),           schemas: [y«rzb»["$defs"]["z"].properties["wptr"], w«y«rzb»»],                                                                          line: __LINE__},
        {ind: rzb, ptr: %w(yabs),           schemas: [y«rzb»["$defs"]["z"].properties["yabs"], y«rzb»],                                                                             line: __LINE__},
        {ind: rzb, ptr: %w(yptr),           schemas: [y«rzb»["$defs"]["z"].properties["yptr"], y«rzb»],                                                                             line: __LINE__},
        {ind: rzb, ptr: %w(x),              schemas: [y«rzb»["$defs"]["z"].properties["x"], x«y«rzb»»],                                                                             line: __LINE__},
        {ind: rzb, ptr: %w(zabsptr),        schemas: [y«rzb»["$defs"]["z"].properties["zabsptr"], y«rzb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rzb, ptr: %w(zptr),           schemas: [y«rzb»["$defs"]["z"].properties["zptr"], y«rzb»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rzb, ptr: %w(x yptr wabs),    schemas: [x«y«rzb»»["$defs"]["y"].properties["wabs"], w«y«rzb»»],                                                                       line: __LINE__},
        {ind: rzb, ptr: %w(x yptr wptr),    schemas: [x«y«rzb»»["$defs"]["y"].properties["wptr"], w«y«rzb»»],                                                                       line: __LINE__},
        {ind: rzb, ptr: %w(x yptr yabs),    schemas: [x«y«rzb»»["$defs"]["y"].properties["yabs"], y«rzb»],                                                                          line: __LINE__},
        {ind: rzb, ptr: %w(x yptr yptr),    schemas: [x«y«rzb»»["$defs"]["y"].properties["yptr"], x«y«rzb»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rzb, ptr: %w(x yptr x),       schemas: [x«y«rzb»»["$defs"]["y"].properties["x"], x«y«rzb»»],                                                                          line: __LINE__},
        {ind: rzb, ptr: %w(x yptr zabsptr), schemas: [x«y«rzb»»["$defs"]["y"].properties["zabsptr"], y«rzb»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rzb, ptr: %w(x yptr zptr),    schemas: [x«y«rzb»»["$defs"]["y"].properties["zptr"], x«y«rzb»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rzb, ptr: %w(x zptr wabs),    schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«rzb»»],                                                         line: __LINE__},
        {ind: rzb, ptr: %w(x zptr wptr),    schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«rzb»»],                                                         line: __LINE__},
        {ind: rzb, ptr: %w(x zptr yabs),    schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rzb»],                                                            line: __LINE__},
        {ind: rzb, ptr: %w(x zptr yptr),    schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«rzb»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rzb, ptr: %w(x zptr x),       schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«rzb»»],                                                            line: __LINE__},
        {ind: rzb, ptr: %w(x zptr zabsptr), schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rzb»["$defs"]["z"]],                                           line: __LINE__},
        {ind: rzb, ptr: %w(x zptr zptr),    schemas: [x«y«rzb»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«rzb»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: rzab, ptr: %w(),               schemas: [rzab, y«rzab»["$defs"]["z"]],                                                                                                 line: __LINE__},
        {ind: rzab, ptr: %w(wabs),           schemas: [y«rzab»["$defs"]["z"].properties["wabs"], w«rzab»],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(wabs wabs),      schemas: [w«rzab».properties["wabs"], w«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(wabs wptr),      schemas: [w«rzab».properties["wptr"], w«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(wabs y),         schemas: [w«rzab».properties["y"], y«rzab»],                                                                                            line: __LINE__},
        {ind: rzab, ptr: %w(wabs x),         schemas: [w«rzab».properties["x"], x«rzab»],                                                                                            line: __LINE__},
        {ind: rzab, ptr: %w(wabs z),         schemas: [w«rzab».properties["z"], y«rzab»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: rzab, ptr: %w(yabs wabs),      schemas: [y«rzab».properties["wabs"], w«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(yabs wptr),      schemas: [y«rzab».properties["wptr"], y«rzab»["$defs"]["z"]["$defs"]["w"]],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(yabs yabs),      schemas: [y«rzab».properties["yabs"], y«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(yabs yptr),      schemas: [y«rzab».properties["yptr"], y«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(yabs x),         schemas: [y«rzab».properties["x"], x«rzab»],                                                                                            line: __LINE__},
        {ind: rzab, ptr: %w(yabs zabsptr),   schemas: [y«rzab».properties["zabsptr"], y«rzab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rzab, ptr: %w(yabs zptr),      schemas: [y«rzab».properties["zptr"], y«rzab»["$defs"]["z"]],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(x wabs),         schemas: [x«rzab».properties["wabs"], w«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(x wptr),         schemas: [x«rzab».properties["wptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rzab, ptr: %w(x yabs),         schemas: [x«rzab».properties["yabs"], y«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(x yptr),         schemas: [x«rzab».properties["yptr"], x«rzab»["$defs"]["y"]],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(x xabs),         schemas: [x«rzab».properties["xabs"], x«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(x xptr),         schemas: [x«rzab».properties["xptr"], x«rzab»],                                                                                         line: __LINE__},
        {ind: rzab, ptr: %w(x zabsptr),      schemas: [x«rzab».properties["zabsptr"], y«rzab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rzab, ptr: %w(x zptr),         schemas: [x«rzab».properties["zptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(wptr),           schemas: [y«rzab»["$defs"]["z"].properties["wptr"], y«rzab»["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rzab, ptr: %w(yabs),           schemas: [y«rzab»["$defs"]["z"].properties["yabs"], y«rzab»],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(yptr),           schemas: [y«rzab»["$defs"]["z"].properties["yptr"], y«rzab»],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(x),              schemas: [y«rzab»["$defs"]["z"].properties["x"], x«rzab»],                                                                              line: __LINE__},
        {ind: rzab, ptr: %w(zabsptr),        schemas: [y«rzab»["$defs"]["z"].properties["zabsptr"], y«rzab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rzab, ptr: %w(zptr),           schemas: [y«rzab»["$defs"]["z"].properties["zptr"], y«rzab»["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(wptr wabs),      schemas: [y«rzab»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rzab»],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(wptr wptr),      schemas: [y«rzab»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rzab»["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rzab, ptr: %w(wptr y),         schemas: [y«rzab»["$defs"]["z"]["$defs"]["w"].properties["y"], y«rzab»],                                                                line: __LINE__},
        {ind: rzab, ptr: %w(wptr x),         schemas: [y«rzab»["$defs"]["z"]["$defs"]["w"].properties["x"], x«rzab»],                                                                line: __LINE__},
        {ind: rzab, ptr: %w(wptr z),         schemas: [y«rzab»["$defs"]["z"]["$defs"]["w"].properties["z"], y«rzab»["$defs"]["z"]],                                                  line: __LINE__},
        {ind: rzab, ptr: %w(x wptr wabs),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rzab»],                                               line: __LINE__},
        {ind: rzab, ptr: %w(x wptr wptr),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],     line: __LINE__},
        {ind: rzab, ptr: %w(x wptr y),       schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«rzab»],                                                  line: __LINE__},
        {ind: rzab, ptr: %w(x wptr x),       schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«rzab»],                                                  line: __LINE__},
        {ind: rzab, ptr: %w(x wptr z),       schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«rzab»["$defs"]["z"]],                                    line: __LINE__},
        {ind: rzab, ptr: %w(x yptr wabs),    schemas: [x«rzab»["$defs"]["y"].properties["wabs"], w«rzab»],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(x yptr wptr),    schemas: [x«rzab»["$defs"]["y"].properties["wptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rzab, ptr: %w(x yptr yabs),    schemas: [x«rzab»["$defs"]["y"].properties["yabs"], y«rzab»],                                                                           line: __LINE__},
        {ind: rzab, ptr: %w(x yptr yptr),    schemas: [x«rzab»["$defs"]["y"].properties["yptr"], x«rzab»["$defs"]["y"]],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(x yptr x),       schemas: [x«rzab»["$defs"]["y"].properties["x"], x«rzab»],                                                                              line: __LINE__},
        {ind: rzab, ptr: %w(x yptr zabsptr), schemas: [x«rzab»["$defs"]["y"].properties["zabsptr"], y«rzab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rzab, ptr: %w(x yptr zptr),    schemas: [x«rzab»["$defs"]["y"].properties["zptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]],                                               line: __LINE__},
        {ind: rzab, ptr: %w(x zptr wabs),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rzab»],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(x zptr wptr),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                   line: __LINE__},
        {ind: rzab, ptr: %w(x zptr yabs),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rzab»],                                                             line: __LINE__},
        {ind: rzab, ptr: %w(x zptr yptr),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rzab»["$defs"]["y"]],                                               line: __LINE__},
        {ind: rzab, ptr: %w(x zptr x),       schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rzab»],                                                                line: __LINE__},
        {ind: rzab, ptr: %w(x zptr zabsptr), schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rzab»["$defs"]["z"]],                                            line: __LINE__},
        {ind: rzab, ptr: %w(x zptr zptr),    schemas: [x«rzab»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rzab»["$defs"]["y"]["$defs"]["z"]],                                 line: __LINE__},

        {ind: w, ptr: %w(),                      schemas: [w],                                                                                                                       line: __LINE__},
        {ind: w, ptr: %w(wabs),                  schemas: [w.properties["wabs"], w],                                                                                                 line: __LINE__},
        {ind: w, ptr: %w(wptr),                  schemas: [w.properties["wptr"], w],                                                                                                 line: __LINE__},
        {ind: w, ptr: %w(y),                     schemas: [w.properties["y"], y«w»],                                                                                                 line: __LINE__},
        {ind: w, ptr: %w(x),                     schemas: [w.properties["x"], x«w»],                                                                                                 line: __LINE__},
        {ind: w, ptr: %w(z),                     schemas: [w.properties["z"], y«w»["$defs"]["z"]],                                                                                   line: __LINE__},
        {ind: w, ptr: %w(y wabs),                schemas: [y«w».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y wptr),                schemas: [y«w».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y yabs),                schemas: [y«w».properties["yabs"], y«w»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y yptr),                schemas: [y«w».properties["yptr"], y«w»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y x),                   schemas: [y«w».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y zabsptr),             schemas: [y«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: w, ptr: %w(y zptr),                schemas: [y«w».properties["zptr"], y«w»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x wabs),                schemas: [x«w».properties["wabs"], w],                                                                                              line: __LINE__},
        {ind: w, ptr: %w(x wptr),                schemas: [x«w».properties["wptr"], x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: w, ptr: %w(x yabs),                schemas: [x«w».properties["yabs"], y«w»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(x yptr),                schemas: [x«w».properties["yptr"], x«w»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x xabs),                schemas: [x«w».properties["xabs"], x«w»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(x xptr),                schemas: [x«w».properties["xptr"], x«w»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(x zabsptr),             schemas: [x«w».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: w, ptr: %w(x zptr),                schemas: [x«w».properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: w, ptr: %w(z wabs),                schemas: [y«w»["$defs"]["z"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(z wptr),                schemas: [y«w»["$defs"]["z"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(z yabs),                schemas: [y«w»["$defs"]["z"].properties["yabs"], y«w»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(z yptr),                schemas: [y«w»["$defs"]["z"].properties["yptr"], y«w»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(z x),                   schemas: [y«w»["$defs"]["z"].properties["x"], x«y«w»»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(z zabsptr),             schemas: [y«w»["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: w, ptr: %w(z zptr),                schemas: [y«w»["$defs"]["z"].properties["zptr"], y«w»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: w, ptr: %w(y wabs wabs),           schemas: [w«y».properties["wabs"], w«y»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y wabs wptr),           schemas: [w«y».properties["wptr"], w«y»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y wabs y),              schemas: [w«y».properties["y"], y«w»],                                                                                              line: __LINE__},
        {ind: w, ptr: %w(y wabs x),              schemas: [w«y».properties["x"], x«y«w»»],                                                                                           line: __LINE__},
        {ind: w, ptr: %w(y wabs z),              schemas: [w«y».properties["z"], y«w»["$defs"]["z"]],                                                                                line: __LINE__},
        {ind: w, ptr: %w(y x wabs),              schemas: [x«y«w»».properties["wabs"], w«y»],                                                                                        line: __LINE__},
        {ind: w, ptr: %w(y x wptr),              schemas: [x«y«w»».properties["wptr"], w«y»],                                                                                        line: __LINE__},
        {ind: w, ptr: %w(y x yabs),              schemas: [x«y«w»».properties["yabs"], y«w»],                                                                                        line: __LINE__},
        {ind: w, ptr: %w(y x yptr),              schemas: [x«y«w»».properties["yptr"], x«y«w»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: w, ptr: %w(y x xabs),              schemas: [x«y«w»».properties["xabs"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: w, ptr: %w(y x xptr),              schemas: [x«y«w»».properties["xptr"], x«y«w»»],                                                                                     line: __LINE__},
        {ind: w, ptr: %w(y x zabsptr),           schemas: [x«y«w»».properties["zabsptr"], y«w»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: w, ptr: %w(y x zptr),              schemas: [x«y«w»».properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: w, ptr: %w(x wptr wabs),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w],                                                    line: __LINE__},
        {ind: w, ptr: %w(x wptr wptr),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: w, ptr: %w(x wptr y),              schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w»],                                                    line: __LINE__},
        {ind: w, ptr: %w(x wptr x),              schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w»],                                                    line: __LINE__},
        {ind: w, ptr: %w(x wptr z),              schemas: [x«w»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w»["$defs"]["z"]],                                      line: __LINE__},
        {ind: w, ptr: %w(x yptr wabs),           schemas: [x«w»["$defs"]["y"].properties["wabs"], w«y»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x yptr wptr),           schemas: [x«w»["$defs"]["y"].properties["wptr"], w«y»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x yptr yabs),           schemas: [x«w»["$defs"]["y"].properties["yabs"], y«w»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x yptr yptr),           schemas: [x«w»["$defs"]["y"].properties["yptr"], x«w»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: w, ptr: %w(x yptr x),              schemas: [x«w»["$defs"]["y"].properties["x"], x«y«w»»],                                                                             line: __LINE__},
        {ind: w, ptr: %w(x yptr zabsptr),        schemas: [x«w»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: w, ptr: %w(x yptr zptr),           schemas: [x«w»["$defs"]["y"].properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: w, ptr: %w(x zptr wabs),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                               line: __LINE__},
        {ind: w, ptr: %w(x zptr wptr),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                               line: __LINE__},
        {ind: w, ptr: %w(x zptr yabs),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                               line: __LINE__},
        {ind: w, ptr: %w(x zptr yptr),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: w, ptr: %w(x zptr x),              schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                               line: __LINE__},
        {ind: w, ptr: %w(x zptr zabsptr),        schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                              line: __LINE__},
        {ind: w, ptr: %w(x zptr zptr),           schemas: [x«w»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},
        {ind: w, ptr: %w(y x yptr wabs),         schemas: [x«y«w»»["$defs"]["y"].properties["wabs"], w«y»],                                                                          line: __LINE__},
        {ind: w, ptr: %w(y x yptr wptr),         schemas: [x«y«w»»["$defs"]["y"].properties["wptr"], w«y»],                                                                          line: __LINE__},
        {ind: w, ptr: %w(y x yptr yabs),         schemas: [x«y«w»»["$defs"]["y"].properties["yabs"], y«w»],                                                                          line: __LINE__},
        {ind: w, ptr: %w(y x yptr yptr),         schemas: [x«y«w»»["$defs"]["y"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: w, ptr: %w(y x yptr x),            schemas: [x«y«w»»["$defs"]["y"].properties["x"], x«y«w»»],                                                                          line: __LINE__},
        {ind: w, ptr: %w(y x yptr zabsptr),      schemas: [x«y«w»»["$defs"]["y"].properties["zabsptr"], y«w»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: w, ptr: %w(y x yptr zptr),         schemas: [x«y«w»»["$defs"]["y"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: w, ptr: %w(y x zptr wabs),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y»],                                                            line: __LINE__},
        {ind: w, ptr: %w(y x zptr wptr),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y»],                                                            line: __LINE__},
        {ind: w, ptr: %w(y x zptr yabs),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w»],                                                            line: __LINE__},
        {ind: w, ptr: %w(y x zptr yptr),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«w»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: w, ptr: %w(y x zptr x),            schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«w»»],                                                            line: __LINE__},
        {ind: w, ptr: %w(y x zptr zabsptr),      schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w»["$defs"]["z"]],                                           line: __LINE__},
        {ind: w, ptr: %w(y x zptr zptr),         schemas: [x«y«w»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«w»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: rwa, ptr: %w(),               schemas: [rwa, w«rwa»],                                                                                                                 line: __LINE__},
        {ind: rwa, ptr: %w(wabs),           schemas: [w«rwa».properties["wabs"], w«rwa»],                                                                                           line: __LINE__},
        {ind: rwa, ptr: %w(wptr),           schemas: [w«rwa».properties["wptr"], w«rwa»],                                                                                           line: __LINE__},
        {ind: rwa, ptr: %w(y),              schemas: [w«rwa».properties["y"], y«w«rwa»»],                                                                                           line: __LINE__},
        {ind: rwa, ptr: %w(x),              schemas: [w«rwa».properties["x"], x«w«rwa»»],                                                                                           line: __LINE__},
        {ind: rwa, ptr: %w(z),              schemas: [w«rwa».properties["z"], y«w«rwa»»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rwa, ptr: %w(y wabs),         schemas: [y«w«rwa»».properties["wabs"], w«rwa»],                                                                                        line: __LINE__},
        {ind: rwa, ptr: %w(y wptr),         schemas: [y«w«rwa»».properties["wptr"], y«w«rwa»»["$defs"]["z"]["$defs"]["w"]],                                                         line: __LINE__},
        {ind: rwa, ptr: %w(y yabs),         schemas: [y«w«rwa»».properties["yabs"], y«w«rwa»»],                                                                                     line: __LINE__},
        {ind: rwa, ptr: %w(y yptr),         schemas: [y«w«rwa»».properties["yptr"], y«w«rwa»»],                                                                                     line: __LINE__},
        {ind: rwa, ptr: %w(y x),            schemas: [y«w«rwa»».properties["x"], x«w«rwa»»],                                                                                        line: __LINE__},
        {ind: rwa, ptr: %w(y zabsptr),      schemas: [y«w«rwa»».properties["zabsptr"], y«w«rwa»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rwa, ptr: %w(y zptr),         schemas: [y«w«rwa»».properties["zptr"], y«w«rwa»»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rwa, ptr: %w(x wabs),         schemas: [x«w«rwa»».properties["wabs"], w«rwa»],                                                                                        line: __LINE__},
        {ind: rwa, ptr: %w(x wptr),         schemas: [x«w«rwa»».properties["wptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rwa, ptr: %w(x yabs),         schemas: [x«w«rwa»».properties["yabs"], y«w«rwa»»],                                                                                     line: __LINE__},
        {ind: rwa, ptr: %w(x yptr),         schemas: [x«w«rwa»».properties["yptr"], x«w«rwa»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rwa, ptr: %w(x xabs),         schemas: [x«w«rwa»».properties["xabs"], x«w«rwa»»],                                                                                     line: __LINE__},
        {ind: rwa, ptr: %w(x xptr),         schemas: [x«w«rwa»».properties["xptr"], x«w«rwa»»],                                                                                     line: __LINE__},
        {ind: rwa, ptr: %w(x zabsptr),      schemas: [x«w«rwa»».properties["zabsptr"], y«w«rwa»»["$defs"]["z"]],                                                                    line: __LINE__},
        {ind: rwa, ptr: %w(x zptr),         schemas: [x«w«rwa»».properties["zptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rwa, ptr: %w(z wabs),         schemas: [y«w«rwa»»["$defs"]["z"].properties["wabs"], w«rwa»],                                                                          line: __LINE__},
        {ind: rwa, ptr: %w(z wptr),         schemas: [y«w«rwa»»["$defs"]["z"].properties["wptr"], y«w«rwa»»["$defs"]["z"]["$defs"]["w"]],                                           line: __LINE__},
        {ind: rwa, ptr: %w(z yabs),         schemas: [y«w«rwa»»["$defs"]["z"].properties["yabs"], y«w«rwa»»],                                                                       line: __LINE__},
        {ind: rwa, ptr: %w(z yptr),         schemas: [y«w«rwa»»["$defs"]["z"].properties["yptr"], y«w«rwa»»],                                                                       line: __LINE__},
        {ind: rwa, ptr: %w(z x),            schemas: [y«w«rwa»»["$defs"]["z"].properties["x"], x«w«rwa»»],                                                                          line: __LINE__},
        {ind: rwa, ptr: %w(z zabsptr),      schemas: [y«w«rwa»»["$defs"]["z"].properties["zabsptr"], y«w«rwa»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rwa, ptr: %w(z zptr),         schemas: [y«w«rwa»»["$defs"]["z"].properties["zptr"], y«w«rwa»»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rwa, ptr: %w(y wptr wabs),    schemas: [y«w«rwa»»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rwa»],                                                            line: __LINE__},
        {ind: rwa, ptr: %w(y wptr wptr),    schemas: [y«w«rwa»»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«w«rwa»»["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rwa, ptr: %w(y wptr y),       schemas: [y«w«rwa»»["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rwa»»],                                                            line: __LINE__},
        {ind: rwa, ptr: %w(y wptr x),       schemas: [y«w«rwa»»["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rwa»»],                                                            line: __LINE__},
        {ind: rwa, ptr: %w(y wptr z),       schemas: [y«w«rwa»»["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rwa»»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rwa, ptr: %w(x wptr wabs),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rwa»],                                              line: __LINE__},
        {ind: rwa, ptr: %w(x wptr wptr),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]], line: __LINE__},
        {ind: rwa, ptr: %w(x wptr y),       schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«w«rwa»»],                                              line: __LINE__},
        {ind: rwa, ptr: %w(x wptr x),       schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«w«rwa»»],                                              line: __LINE__},
        {ind: rwa, ptr: %w(x wptr z),       schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«w«rwa»»["$defs"]["z"]],                                line: __LINE__},
        {ind: rwa, ptr: %w(x yptr wabs),    schemas: [x«w«rwa»»["$defs"]["y"].properties["wabs"], w«rwa»],                                                                          line: __LINE__},
        {ind: rwa, ptr: %w(x yptr wptr),    schemas: [x«w«rwa»»["$defs"]["y"].properties["wptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                             line: __LINE__},
        {ind: rwa, ptr: %w(x yptr yabs),    schemas: [x«w«rwa»»["$defs"]["y"].properties["yabs"], y«w«rwa»»],                                                                       line: __LINE__},
        {ind: rwa, ptr: %w(x yptr yptr),    schemas: [x«w«rwa»»["$defs"]["y"].properties["yptr"], x«w«rwa»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rwa, ptr: %w(x yptr x),       schemas: [x«w«rwa»»["$defs"]["y"].properties["x"], x«w«rwa»»],                                                                          line: __LINE__},
        {ind: rwa, ptr: %w(x yptr zabsptr), schemas: [x«w«rwa»»["$defs"]["y"].properties["zabsptr"], y«w«rwa»»["$defs"]["z"]],                                                      line: __LINE__},
        {ind: rwa, ptr: %w(x yptr zptr),    schemas: [x«w«rwa»»["$defs"]["y"].properties["zptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rwa, ptr: %w(x zptr wabs),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rwa»],                                                            line: __LINE__},
        {ind: rwa, ptr: %w(x zptr wptr),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],               line: __LINE__},
        {ind: rwa, ptr: %w(x zptr yabs),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«w«rwa»»],                                                         line: __LINE__},
        {ind: rwa, ptr: %w(x zptr yptr),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«w«rwa»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rwa, ptr: %w(x zptr x),       schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«w«rwa»»],                                                            line: __LINE__},
        {ind: rwa, ptr: %w(x zptr zabsptr), schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«w«rwa»»["$defs"]["z"]],                                        line: __LINE__},
        {ind: rwa, ptr: %w(x zptr zptr),    schemas: [x«w«rwa»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«w«rwa»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: rwb, ptr: %w(),                 schemas: [rwb, w«rwb»],                                                                                                                 line: __LINE__},
        {ind: rwb, ptr: %w(wabs),             schemas: [w«rwb».properties["wabs"], w«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(wptr),             schemas: [w«rwb».properties["wptr"], w«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(y),                schemas: [w«rwb».properties["y"], y«rwb»],                                                                                              line: __LINE__},
        {ind: rwb, ptr: %w(x),                schemas: [w«rwb».properties["x"], x«rwb»],                                                                                              line: __LINE__},
        {ind: rwb, ptr: %w(z),                schemas: [w«rwb».properties["z"], y«rwb»["$defs"]["z"]],                                                                                line: __LINE__},
        {ind: rwb, ptr: %w(y wabs),           schemas: [y«rwb».properties["wabs"], w«y«rwb»»],                                                                                        line: __LINE__},
        {ind: rwb, ptr: %w(y wptr),           schemas: [y«rwb».properties["wptr"], w«y«rwb»»],                                                                                        line: __LINE__},
        {ind: rwb, ptr: %w(y yabs),           schemas: [y«rwb».properties["yabs"], y«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(y yptr),           schemas: [y«rwb».properties["yptr"], y«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(y x),              schemas: [y«rwb».properties["x"], x«y«rwb»»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(y zabsptr),        schemas: [y«rwb».properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(y zptr),           schemas: [y«rwb».properties["zptr"], y«rwb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(x wabs),           schemas: [x«rwb».properties["wabs"], w«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(x wptr),           schemas: [x«rwb».properties["wptr"], x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                                 line: __LINE__},
        {ind: rwb, ptr: %w(x yabs),           schemas: [x«rwb».properties["yabs"], y«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(x yptr),           schemas: [x«rwb».properties["yptr"], x«rwb»["$defs"]["y"]],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(x xabs),           schemas: [x«rwb».properties["xabs"], x«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(x xptr),           schemas: [x«rwb».properties["xptr"], x«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(x zabsptr),        schemas: [x«rwb».properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(x zptr),           schemas: [x«rwb».properties["zptr"], x«rwb»["$defs"]["y"]["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rwb, ptr: %w(z wabs),           schemas: [y«rwb»["$defs"]["z"].properties["wabs"], w«y«rwb»»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(z wptr),           schemas: [y«rwb»["$defs"]["z"].properties["wptr"], w«y«rwb»»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(z yabs),           schemas: [y«rwb»["$defs"]["z"].properties["yabs"], y«rwb»],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(z yptr),           schemas: [y«rwb»["$defs"]["z"].properties["yptr"], y«rwb»],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(z x),              schemas: [y«rwb»["$defs"]["z"].properties["x"], x«y«rwb»»],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(z zabsptr),        schemas: [y«rwb»["$defs"]["z"].properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(z zptr),           schemas: [y«rwb»["$defs"]["z"].properties["zptr"], y«rwb»["$defs"]["z"]],                                                               line: __LINE__},
        {ind: rwb, ptr: %w(y wabs wabs),      schemas: [w«y«rwb»».properties["wabs"], w«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y wabs wptr),      schemas: [w«y«rwb»».properties["wptr"], w«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y wabs y),         schemas: [w«y«rwb»».properties["y"], y«rwb»],                                                                                           line: __LINE__},
        {ind: rwb, ptr: %w(y wabs x),         schemas: [w«y«rwb»».properties["x"], x«y«rwb»»],                                                                                        line: __LINE__},
        {ind: rwb, ptr: %w(y wabs z),         schemas: [w«y«rwb»».properties["z"], y«rwb»["$defs"]["z"]],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(y x wabs),         schemas: [x«y«rwb»».properties["wabs"], w«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y x wptr),         schemas: [x«y«rwb»».properties["wptr"], w«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y x yabs),         schemas: [x«y«rwb»».properties["yabs"], y«rwb»],                                                                                        line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr),         schemas: [x«y«rwb»».properties["yptr"], x«y«rwb»»["$defs"]["y"]],                                                                       line: __LINE__},
        {ind: rwb, ptr: %w(y x xabs),         schemas: [x«y«rwb»».properties["xabs"], x«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y x xptr),         schemas: [x«y«rwb»».properties["xptr"], x«y«rwb»»],                                                                                     line: __LINE__},
        {ind: rwb, ptr: %w(y x zabsptr),      schemas: [x«y«rwb»».properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                                       line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr),         schemas: [x«y«rwb»».properties["zptr"], x«y«rwb»»["$defs"]["y"]["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rwb, ptr: %w(x wptr wabs),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rwb»],                                                 line: __LINE__},
        {ind: rwb, ptr: %w(x wptr wptr),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],       line: __LINE__},
        {ind: rwb, ptr: %w(x wptr y),         schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«rwb»],                                                    line: __LINE__},
        {ind: rwb, ptr: %w(x wptr x),         schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«rwb»],                                                    line: __LINE__},
        {ind: rwb, ptr: %w(x wptr z),         schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«rwb»["$defs"]["z"]],                                      line: __LINE__},
        {ind: rwb, ptr: %w(x yptr wabs),      schemas: [x«rwb»["$defs"]["y"].properties["wabs"], w«y«rwb»»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(x yptr wptr),      schemas: [x«rwb»["$defs"]["y"].properties["wptr"], w«y«rwb»»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(x yptr yabs),      schemas: [x«rwb»["$defs"]["y"].properties["yabs"], y«rwb»],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(x yptr yptr),      schemas: [x«rwb»["$defs"]["y"].properties["yptr"], x«rwb»["$defs"]["y"]],                                                               line: __LINE__},
        {ind: rwb, ptr: %w(x yptr x),         schemas: [x«rwb»["$defs"]["y"].properties["x"], x«y«rwb»»],                                                                             line: __LINE__},
        {ind: rwb, ptr: %w(x yptr zabsptr),   schemas: [x«rwb»["$defs"]["y"].properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(x yptr zptr),      schemas: [x«rwb»["$defs"]["y"].properties["zptr"], x«rwb»["$defs"]["y"]["$defs"]["z"]],                                                 line: __LINE__},
        {ind: rwb, ptr: %w(x zptr wabs),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«rwb»»],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(x zptr wptr),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«rwb»»],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(x zptr yabs),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rwb»],                                                               line: __LINE__},
        {ind: rwb, ptr: %w(x zptr yptr),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rwb»["$defs"]["y"]],                                                 line: __LINE__},
        {ind: rwb, ptr: %w(x zptr x),         schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«rwb»»],                                                               line: __LINE__},
        {ind: rwb, ptr: %w(x zptr zabsptr),   schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rwb»["$defs"]["z"]],                                              line: __LINE__},
        {ind: rwb, ptr: %w(x zptr zptr),      schemas: [x«rwb»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rwb»["$defs"]["y"]["$defs"]["z"]],                                   line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr wabs),    schemas: [x«y«rwb»»["$defs"]["y"].properties["wabs"], w«y«rwb»»],                                                                       line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr wptr),    schemas: [x«y«rwb»»["$defs"]["y"].properties["wptr"], w«y«rwb»»],                                                                       line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr yabs),    schemas: [x«y«rwb»»["$defs"]["y"].properties["yabs"], y«rwb»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr yptr),    schemas: [x«y«rwb»»["$defs"]["y"].properties["yptr"], x«y«rwb»»["$defs"]["y"]],                                                         line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr x),       schemas: [x«y«rwb»»["$defs"]["y"].properties["x"], x«y«rwb»»],                                                                          line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr zabsptr), schemas: [x«y«rwb»»["$defs"]["y"].properties["zabsptr"], y«rwb»["$defs"]["z"]],                                                         line: __LINE__},
        {ind: rwb, ptr: %w(y x yptr zptr),    schemas: [x«y«rwb»»["$defs"]["y"].properties["zptr"], x«y«rwb»»["$defs"]["y"]["$defs"]["z"]],                                           line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr wabs),    schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«y«rwb»»],                                                         line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr wptr),    schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["wptr"], w«y«rwb»»],                                                         line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr yabs),    schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rwb»],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr yptr),    schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«y«rwb»»["$defs"]["y"]],                                           line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr x),       schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["x"], x«y«rwb»»],                                                            line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr zabsptr), schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rwb»["$defs"]["z"]],                                           line: __LINE__},
        {ind: rwb, ptr: %w(y x zptr zptr),    schemas: [x«y«rwb»»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«y«rwb»»["$defs"]["y"]["$defs"]["z"]],                             line: __LINE__},

        {ind: rwab, ptr: %w(),               schemas: [rwab, w«rwab»],                                                                                                               line: __LINE__},
        {ind: rwab, ptr: %w(wabs),           schemas: [w«rwab».properties["wabs"], w«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(wptr),           schemas: [w«rwab».properties["wptr"], w«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(y),              schemas: [w«rwab».properties["y"], y«rwab»],                                                                                            line: __LINE__},
        {ind: rwab, ptr: %w(x),              schemas: [w«rwab».properties["x"], x«rwab»],                                                                                            line: __LINE__},
        {ind: rwab, ptr: %w(z),              schemas: [w«rwab».properties["z"], y«rwab»["$defs"]["z"]],                                                                              line: __LINE__},
        {ind: rwab, ptr: %w(y wabs),         schemas: [y«rwab».properties["wabs"], w«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(y wptr),         schemas: [y«rwab».properties["wptr"], y«rwab»["$defs"]["z"]["$defs"]["w"]],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(y yabs),         schemas: [y«rwab».properties["yabs"], y«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(y yptr),         schemas: [y«rwab».properties["yptr"], y«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(y x),            schemas: [y«rwab».properties["x"], x«rwab»],                                                                                            line: __LINE__},
        {ind: rwab, ptr: %w(y zabsptr),      schemas: [y«rwab».properties["zabsptr"], y«rwab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rwab, ptr: %w(y zptr),         schemas: [y«rwab».properties["zptr"], y«rwab»["$defs"]["z"]],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(x wabs),         schemas: [x«rwab».properties["wabs"], w«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(x wptr),         schemas: [x«rwab».properties["wptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rwab, ptr: %w(x yabs),         schemas: [x«rwab».properties["yabs"], y«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(x yptr),         schemas: [x«rwab».properties["yptr"], x«rwab»["$defs"]["y"]],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(x xabs),         schemas: [x«rwab».properties["xabs"], x«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(x xptr),         schemas: [x«rwab».properties["xptr"], x«rwab»],                                                                                         line: __LINE__},
        {ind: rwab, ptr: %w(x zabsptr),      schemas: [x«rwab».properties["zabsptr"], y«rwab»["$defs"]["z"]],                                                                        line: __LINE__},
        {ind: rwab, ptr: %w(x zptr),         schemas: [x«rwab».properties["zptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(z wabs),         schemas: [y«rwab»["$defs"]["z"].properties["wabs"], w«rwab»],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(z wptr),         schemas: [y«rwab»["$defs"]["z"].properties["wptr"], y«rwab»["$defs"]["z"]["$defs"]["w"]],                                               line: __LINE__},
        {ind: rwab, ptr: %w(z yabs),         schemas: [y«rwab»["$defs"]["z"].properties["yabs"], y«rwab»],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(z yptr),         schemas: [y«rwab»["$defs"]["z"].properties["yptr"], y«rwab»],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(z x),            schemas: [y«rwab»["$defs"]["z"].properties["x"], x«rwab»],                                                                              line: __LINE__},
        {ind: rwab, ptr: %w(z zabsptr),      schemas: [y«rwab»["$defs"]["z"].properties["zabsptr"], y«rwab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rwab, ptr: %w(z zptr),         schemas: [y«rwab»["$defs"]["z"].properties["zptr"], y«rwab»["$defs"]["z"]],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(y wptr wabs),    schemas: [y«rwab»["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rwab»],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(y wptr wptr),    schemas: [y«rwab»["$defs"]["z"]["$defs"]["w"].properties["wptr"], y«rwab»["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rwab, ptr: %w(y wptr y),       schemas: [y«rwab»["$defs"]["z"]["$defs"]["w"].properties["y"], y«rwab»],                                                                line: __LINE__},
        {ind: rwab, ptr: %w(y wptr x),       schemas: [y«rwab»["$defs"]["z"]["$defs"]["w"].properties["x"], x«rwab»],                                                                line: __LINE__},
        {ind: rwab, ptr: %w(y wptr z),       schemas: [y«rwab»["$defs"]["z"]["$defs"]["w"].properties["z"], y«rwab»["$defs"]["z"]],                                                  line: __LINE__},
        {ind: rwab, ptr: %w(x wptr wabs),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wabs"], w«rwab»],                                               line: __LINE__},
        {ind: rwab, ptr: %w(x wptr wptr),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["wptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],     line: __LINE__},
        {ind: rwab, ptr: %w(x wptr y),       schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["y"], y«rwab»],                                                  line: __LINE__},
        {ind: rwab, ptr: %w(x wptr x),       schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["x"], x«rwab»],                                                  line: __LINE__},
        {ind: rwab, ptr: %w(x wptr z),       schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"].properties["z"], y«rwab»["$defs"]["z"]],                                    line: __LINE__},
        {ind: rwab, ptr: %w(x yptr wabs),    schemas: [x«rwab»["$defs"]["y"].properties["wabs"], w«rwab»],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(x yptr wptr),    schemas: [x«rwab»["$defs"]["y"].properties["wptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                                 line: __LINE__},
        {ind: rwab, ptr: %w(x yptr yabs),    schemas: [x«rwab»["$defs"]["y"].properties["yabs"], y«rwab»],                                                                           line: __LINE__},
        {ind: rwab, ptr: %w(x yptr yptr),    schemas: [x«rwab»["$defs"]["y"].properties["yptr"], x«rwab»["$defs"]["y"]],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(x yptr x),       schemas: [x«rwab»["$defs"]["y"].properties["x"], x«rwab»],                                                                              line: __LINE__},
        {ind: rwab, ptr: %w(x yptr zabsptr), schemas: [x«rwab»["$defs"]["y"].properties["zabsptr"], y«rwab»["$defs"]["z"]],                                                          line: __LINE__},
        {ind: rwab, ptr: %w(x yptr zptr),    schemas: [x«rwab»["$defs"]["y"].properties["zptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]],                                               line: __LINE__},
        {ind: rwab, ptr: %w(x zptr wabs),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["wabs"], w«rwab»],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(x zptr wptr),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["wptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]["$defs"]["w"]],                   line: __LINE__},
        {ind: rwab, ptr: %w(x zptr yabs),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["yabs"], y«rwab»],                                                             line: __LINE__},
        {ind: rwab, ptr: %w(x zptr yptr),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["yptr"], x«rwab»["$defs"]["y"]],                                               line: __LINE__},
        {ind: rwab, ptr: %w(x zptr x),       schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["x"], x«rwab»],                                                                line: __LINE__},
        {ind: rwab, ptr: %w(x zptr zabsptr), schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["zabsptr"], y«rwab»["$defs"]["z"]],                                            line: __LINE__},
        {ind: rwab, ptr: %w(x zptr zptr),    schemas: [x«rwab»["$defs"]["y"]["$defs"]["z"].properties["zptr"], x«rwab»["$defs"]["y"]["$defs"]["z"]],                                 line: __LINE__},
      ]

      # instance content: make an instance with a node at each expected ptr
      ic = {}
      exps.each do |exp|
        iccur = ic
        exp[:ptr].each do |token|
          iccur[token] ||= {}
          iccur = iccur[token]
        end
      end

      # instances hash: make an instance for the given indicated schema
      is = Hash.new do |h, ind|
        h[ind] = ind.new_jsi(ic)
      end

      exps.map(&:values).each do |(ind, ptr, schemas, line)|
        assert_schemas(schemas, is[ind] / ptr, -"#{Pathname.new(__FILE__).relative_path_from(JSI::ROOT_PATH)}:#{line}")
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
