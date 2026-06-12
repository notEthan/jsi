require_relative('test_helper')

describe("https://one.sourcemeta.com/guide/using-custom-metaschemas/") do
  let(:metaschema) do
    JSI.new_schema(
      metaschema_content,
      stringify_symbol_keys: true,
      root_uri: metaschema_root_uri,
    ).tap(&:describes_schema!)
  end

  describe("step 1") do
    let(:metaschema_root_uri) { "http://localhost:8000/meta/custom" }

    let(:metaschema_content) do
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/core": true,
          "https://json-schema.org/draft/2020-12/vocab/applicator": true,
          "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
          "https://json-schema.org/draft/2020-12/vocab/validation": true,
          "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
          "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
          "https://json-schema.org/draft/2020-12/vocab/content": true
        },
        "$dynamicAnchor": "meta",
        "title": "Custom Meta-Schema",
        "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
        "allOf": [
          { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
          { "$ref": "https://json-schema.org/draft/2020-12/meta/content" }
        ]
      }
    end

    it("has a meta-schema") do
      assert(metaschema.describes_schema?)
    end

    describe("step 2") do
      let(:person_schema_1) do
        metaschema.new_schema({
          "title": "Person",
          "description": "A simple schema for describing a person",
          "examples": [
            {
              "name": "John Doe",
              "country": "United States of America",
              "postalCode": "10001"
            }
          ],
          "type": "object",
          "required": [ "name" ],
          "properties": {
            "name": {
              "type": "string"
            },
            "country": {
              "type": "string"
            },
            "postalCode": {
              "type": "string"
            }
          },
          "if": {
            "properties": {
              "country": {
                "const": "United States of America"
              }
            }
          },
          "then": {
            "properties": {
              "postalCode": {
                "pattern": "^[0-9]{5}(-[0-9]{4})?$"
              }
            }
          }
        })
      end

      it("person schema valid") do
        person_schema_1.jsi_valid!
      end

      describe("step 3") do
        let(:meta_no_conditionals) do
          JSI.new_schema(
            {
              "$schema": "https://json-schema.org/draft/2020-12/schema",
              "$vocabulary": {
                "https://json-schema.org/draft/2020-12/vocab/core": true
              },
              "title": "No Conditionals Rule",
              "description": "You must not use the if, then, and else applicator keywords",
              "properties": {
                "if": false,
                "then": false,
                "else": false
              }
            },
            root_uri: "http://localhost:8000/meta/rules/circular/no-conditionals.json",
            stringify_symbol_keys: true,
          )
        end
        before { meta_no_conditionals } # register

        let(:metaschema_content) do
          {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://json-schema.org/draft/2020-12/vocab/applicator": true,
              "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
              "https://json-schema.org/draft/2020-12/vocab/validation": true,
              "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
              "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
              "https://json-schema.org/draft/2020-12/vocab/content": true
            },
            "$dynamicAnchor": "meta",
            "title": "Custom Meta-Schema",
            "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
            "allOf": [
              { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
              { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
              { "$ref": "rules/circular/no-conditionals.json" }
            ]
          }
        end

        let(:person_schema_no_conditionals) do
          person_schema_1.except('if', 'then')
        end

        it("person schema invalid with if/then; valid without") do
          result = person_schema_1.jsi_validate
          exp = [
            [JSI::Ptr['if'], JSI::URI["http://localhost:8000/meta/rules/circular/no-conditionals.json#/properties/if"], nil],
            [JSI::Ptr['then'], JSI::URI["http://localhost:8000/meta/rules/circular/no-conditionals.json#/properties/then"], nil],
          ]
          assert_equal(exp, result.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
          person_schema_no_conditionals.jsi_valid!
        end

        describe("step 4") do
          let(:meta_object_additional_properties) do
            JSI.new_schema(
              {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$vocabulary": {
                  "https://json-schema.org/draft/2020-12/vocab/core": true
                },
                "title": "Object Additional Properties Rule",
                "description": "You must declare additionalProperties when type is or contains object",
                "if": {
                  "required": [ "type" ],
                  "properties": {
                    "type": {
                      "anyOf": [
                        { "const": "object" },
                        { "type": "array", "contains": { "const": "object" } }
                      ]
                    }
                  }
                },
                "then": {
                  "required": [ "additionalProperties" ],
                  "properties": {
                    "additionalProperties": true
                  }
                }
              },
              root_uri: "http://localhost:8000/meta/rules/circular/object-additional-properties.json",
              stringify_symbol_keys: true,
            )
          end
          before { meta_object_additional_properties } # register

          let(:metaschema_content) do
            {
              "$schema": "https://json-schema.org/draft/2020-12/schema",
              "$vocabulary": {
                "https://json-schema.org/draft/2020-12/vocab/core": true,
                "https://json-schema.org/draft/2020-12/vocab/applicator": true,
                "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
                "https://json-schema.org/draft/2020-12/vocab/validation": true,
                "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
                "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
                "https://json-schema.org/draft/2020-12/vocab/content": true
              },
              "$dynamicAnchor": "meta",
              "title": "Custom Meta-Schema",
              "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
              "allOf": [
                { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                { "$ref": "rules/circular/object-additional-properties.json" },
                { "$ref": "rules/circular/no-conditionals.json" }
              ]
            }
          end


          let(:person_schema_additionalProperties) do
            person_schema_no_conditionals.merge('additionalProperties' => false)
          end

          it("person schema invalid without additionalProperties; valid with") do
            result = person_schema_no_conditionals.jsi_validate
            exp = [
              [JSI::Ptr[], JSI::URI["http://localhost:8000/meta/rules/circular/object-additional-properties.json#/then"], 'required'],
            ]
            assert_equal(exp, result.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
            person_schema_additionalProperties.jsi_valid!
          end

          describe("step 5") do
            before do
              JSI.new_schema(
                {
                  "$schema": "https://json-schema.org/draft/2020-12/schema",
                  "$vocabulary": {
                    "https://json-schema.org/draft/2020-12/vocab/core": true
                  },
                  "title": "Author Keyword",
                  "description": "Keyword for attributing schemas to their authors",
                  "properties": {
                    "x-author": {
                      "description": "The author of the schema",
                      "type": "string"
                    }
                  }
                },
                root_uri: "http://localhost:8000/meta/keywords/x-author.json",
                stringify_symbol_keys: true,
              )
            end

            let(:metaschema_content) do
              {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$vocabulary": {
                  "https://json-schema.org/draft/2020-12/vocab/core": true,
                  "https://json-schema.org/draft/2020-12/vocab/applicator": true,
                  "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
                  "https://json-schema.org/draft/2020-12/vocab/validation": true,
                  "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
                  "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
                  "https://json-schema.org/draft/2020-12/vocab/content": true
                },
                "$dynamicAnchor": "meta",
                "title": "Custom Meta-Schema",
                "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
                "allOf": [
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                  { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                  { "$ref": "keywords/x-author.json" },
                  { "$ref": "rules/circular/object-additional-properties.json" },
                  { "$ref": "rules/circular/no-conditionals.json" }
                ]
              }
            end

            let(:person_authorjane) do
              metaschema.new_schema({
                "x-author": "Jane Doe",
                "title": "Person",
                "description": "A simple schema for describing a person",
                "examples": [
                  {
                    "name": "John Doe",
                    "country": "United States of America",
                    "postalCode": "10001"
                  }
                ],
                "type": "object",
                "required": [ "name" ],
                "properties": {
                  "name": {
                    "type": "string"
                  },
                  "country": {
                    "type": "string"
                  },
                  "postalCode": {
                    "type": "string"
                  }
                },
                "additionalProperties": false
              })
            end

            # the content is reiterated in the step 5; sanity check edits are consistent with expected
            it("person_authorjane consistency") do
              assert_equal(person_authorjane, metaschema.new_schema({'x-author' => "Jane Doe"}.merge(person_schema_additionalProperties.jsi_node_content)))
            end

            it("person schema invalid with non-string x-author; valid with string") do
              person_author1 = person_schema_additionalProperties.merge('x-author' => 1)
              exp = [
                [JSI::Ptr['x-author'], JSI::URI["http://localhost:8000/meta/keywords/x-author.json#/properties/x-author"], 'type'],
              ]
              assert_equal(exp, person_author1.jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
              person_authorjane.jsi_valid!
            end

            describe("step 6") do
              before do
                JSI.new_schema(
                  {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$vocabulary": {
                      "https://json-schema.org/draft/2020-12/vocab/core": true
                    },
                    "title": "Author Required Rule",
                    "description": "You must declare the x-author keyword at the top level",
                    "required": [ "x-author" ],
                    "properties": {
                      "x-author": true
                    }
                  },
                  root_uri: "http://localhost:8000/meta/rules/top/x-author-required.json",
                  stringify_symbol_keys: true,
                )
              end

              describe("x-author required recursive") do
                let(:metaschema_content) do
                  {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$vocabulary": {
                      "https://json-schema.org/draft/2020-12/vocab/core": true,
                      "https://json-schema.org/draft/2020-12/vocab/applicator": true,
                      "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
                      "https://json-schema.org/draft/2020-12/vocab/validation": true,
                      "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
                      "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
                      "https://json-schema.org/draft/2020-12/vocab/content": true
                    },
                    "$dynamicAnchor": "meta",
                    "title": "Custom Meta-Schema",
                    "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
                    "allOf": [
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                      { "$ref": "rules/circular/object-additional-properties.json" },
                      { "$ref": "rules/circular/no-conditionals.json" },
                      { "$ref": "rules/top/x-author-required.json" }
                    ]
                  }
                end

                it("person schema invalid without x-author on every subschema") do
                  exp = [
                    [JSI::Ptr["properties", "name"], JSI::URI["http://localhost:8000/meta/rules/top/x-author-required.json"], 'required'],
                    [JSI::Ptr["properties", "country"], JSI::URI["http://localhost:8000/meta/rules/top/x-author-required.json"], 'required'],
                    [JSI::Ptr["properties", "postalCode"], JSI::URI["http://localhost:8000/meta/rules/top/x-author-required.json"], 'required'],
                  ]
                  assert_equal(exp, person_authorjane.jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                end
              end

              describe("x-author required at root, not recursive") do
                let(:metaschema_recursive_content) do
                  {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$dynamicAnchor": "meta",
                    "title": "Circular Schema",
                    "description": "The recursive definition that applies to every nested subschema",
                    "allOf": [
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                      { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                      { "$ref": "keywords/x-author.json" },
                      { "$ref": "rules/circular/object-additional-properties.json" },
                      { "$ref": "rules/circular/no-conditionals.json" }
                    ]
                  }
                end
                let(:metaschema_recursive) do
                  JSI.new_schema(
                    metaschema_recursive_content,
                    root_uri: "http://localhost:8000/meta/circular.json",
                    stringify_symbol_keys: true,
                  )
                end
                before do
                  # this is the same dialect as 2020-12 since no other vocabularies are included, but it is slightly more conceptually correct to construct it this way I guess
                  dialect = JSI::Schema::Dialect.from_xvocabulary(JSI::Util.deep_stringify_symbol_keys(metaschema_content)['$vocabulary'])
                  # it is weird to describes_schema! both this and `metaschema`. both will include Schema and define #dialect on their instances; which one overrides the other is undefined. it doesn't matter here because the dialects are equal.
                  metaschema_recursive.describes_schema!(dialect)
                end

                let(:metaschema_content) do
                  {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$vocabulary": {
                      "https://json-schema.org/draft/2020-12/vocab/core": true,
                      "https://json-schema.org/draft/2020-12/vocab/applicator": true,
                      "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
                      "https://json-schema.org/draft/2020-12/vocab/validation": true,
                      "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
                      "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
                      "https://json-schema.org/draft/2020-12/vocab/content": true
                    },
                    "title": "Custom Meta-Schema",
                    "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
                    "allOf": [
                      { "$ref": "circular.json" },
                      { "$ref": "rules/top/x-author-required.json" }
                    ]
                  }
                end

                it("person schema valid with x-author at root; invalid without") do
                  person_authorjane.jsi_valid!
                  exp = [
                    [JSI::Ptr[], JSI::URI["http://localhost:8000/meta/rules/top/x-author-required.json"], 'required'],
                  ]
                  assert_equal(exp, person_schema_additionalProperties.jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                end

                describe("metaschema no describes_schema!; metaschema_recursive does") do
                  # experiment: the metaschema doesn't actually have to describes_schema! here. the metaschema_recursive does. override #metaschema to be a plain schema.
                  # but if metaschema does not describes_schema! then #new_schema is not defined so (hax) extend metaschema with JSI::Schema::MetaSchema - as describes_schema! would do, but without defining #dialect / #metaschema
                  let(:metaschema) do
                    JSI.new_schema(
                      metaschema_content,
                      stringify_symbol_keys: true,
                      root_uri: "http://localhost:8000/meta/custom",
                    ).tap { |m| m.extend(JSI::Schema::MetaSchema) }
                  end

                  it("person schema valid with x-author at root; invalid without") do
                    person_authorjane.jsi_valid!
                    exp = [
                      [JSI::Ptr[], JSI::URI["http://localhost:8000/meta/rules/top/x-author-required.json"], 'required'],
                    ]
                    assert_equal(exp, person_schema_additionalProperties.jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                  end
                end

                describe("step 7") do
                  let(:metaschema_recursive_content) do
                    {
                      "$schema": "https://json-schema.org/draft/2020-12/schema",
                      "$dynamicAnchor": "meta",
                      "title": "Circular Schema",
                      "description": "The recursive definition that applies to every nested subschema",
                      "allOf": [
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/unevaluated" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                        { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                        { "$ref": "keywords/x-author.json" },
                        { "$ref": "rules/circular/object-additional-properties.json" },
                        { "$ref": "rules/circular/no-conditionals.json" }
                      ],
                      "unevaluatedProperties": false
                    }
                  end

                  it("person schema valid without unevaluated properties; invalid with") do
                    person_authorjane.jsi_valid!
                    exp = [
                      [JSI::Ptr["x-team"], JSI::URI["http://localhost:8000/meta/circular.json#/unevaluatedProperties"], nil],
                    ]
                    assert_equal(exp, person_authorjane.merge("x-team" => "Growth").jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                  end

                  describe("step 8") do
                    let(:metaschema_content) do
                      {
                        "$schema": "https://json-schema.org/draft/2020-12/schema",
                        "$vocabulary": {
                          "https://json-schema.org/draft/2020-12/vocab/core": true,
                          "https://json-schema.org/draft/2020-12/vocab/applicator": true,
                          "https://json-schema.org/draft/2020-12/vocab/validation": true,
                          "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
                          "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
                          "https://json-schema.org/draft/2020-12/vocab/content": true
                        },
                        "title": "Custom Meta-Schema",
                        "description": "An extension of JSON Schema 2020-12 with custom keywords and rules",
                        "allOf": [
                          { "$ref": "circular.json" },
                          { "$ref": "rules/top/x-author-required.json" }
                        ]
                      }
                    end

                    let(:metaschema_recursive_content) do
                      {
                        "$schema": "https://json-schema.org/draft/2020-12/schema",
                        "$dynamicAnchor": "meta",
                        "title": "Circular Schema",
                        "description": "The recursive definition that applies to every nested subschema",
                        "allOf": [
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/core" },
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/applicator" },
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/validation" },
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/meta-data" },
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/format-annotation" },
                          { "$ref": "https://json-schema.org/draft/2020-12/meta/content" },
                          { "$ref": "keywords/x-author.json" },
                          { "$ref": "rules/circular/object-additional-properties.json" },
                          { "$ref": "rules/circular/no-conditionals.json" }
                        ],
                        "unevaluatedProperties": false
                      }
                    end

                    it("person schema valid without unevaluated properties; invalid with") do
                      person_authorjane.jsi_valid!
                      exp = [
                        [JSI::Ptr["x-team"], JSI::URI["http://localhost:8000/meta/circular.json#/unevaluatedProperties"], nil],
                      ]
                      assert_equal(exp, person_authorjane.merge("x-team" => "Growth").jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                      exp = [
                        [JSI::Ptr["unevaluatedProperties"], JSI::URI["http://localhost:8000/meta/circular.json#/unevaluatedProperties"], nil],
                      ]
                      assert_equal(exp, person_authorjane.merge("unevaluatedProperties" => false).jsi_validate.each_leaf_validation_error.map { |e| [e.instance_ptr, e.schema.schema_uri, e.keyword] })
                    end

                    describe("step 9") do
                      it("schema tests") do
                        schema_tests_wrapper_content = JSI::Util.deep_stringify_symbol_keys({
                          "target": "../../schemas/meta/custom.json",
                          "tests": [
                            {
                              "description": "The empty object is invalid as the author keyword is required",
                              "valid": false,
                              "data": {}
                            },
                            {
                              "description": "An object that only declares an author is valid",
                              "valid": true,
                              "data": {
                                "x-author": "Jane Doe"
                              }
                            },
                            {
                              "description": "The author keyword must be a string",
                              "valid": false,
                              "data": {
                                "x-author": 1
                              }
                            },
                            {
                              "description": "Nested subschemas do not require an author",
                              "valid": true,
                              "data": {
                                "x-author": "Jane Doe",
                                "properties": {
                                  "name": {
                                    "type": "string"
                                  }
                                }
                              }
                            },
                            {
                              "description": "The conditional keywords are disallowed in nested subschemas",
                              "valid": false,
                              "data": {
                                "x-author": "Jane Doe",
                                "properties": {
                                  "name": {
                                    "if": true
                                  }
                                }
                              }
                            },
                            {
                              "description": "An object type schema must declare additionalProperties",
                              "valid": false,
                              "data": {
                                "x-author": "Jane Doe",
                                "type": "object"
                              }
                            },
                            {
                              "description": "Keywords not defined by the dialect are disallowed",
                              "valid": false,
                              "data": {
                                "x-author": "Jane Doe",
                                "x-team": "Growth"
                              }
                            },
                            {
                              "description": "The unevaluated applicator keywords are not part of the dialect",
                              "valid": false,
                              "data": {
                                "x-author": "Jane Doe",
                                "unevaluatedProperties": false
                              }
                            }
                          ]
                        })

                        schema_tests_wrapper_content['tests'].each do |test_content|
                          schema = metaschema.new_schema(test_content['data'])
                          result = schema.jsi_validate
                          assert_equal(
                            test_content['valid'],
                            result.valid?,
                          )
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
