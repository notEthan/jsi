# frozen_string_literal: true

require_relative 'test_helper'

# the behaviors described in these tests are not officially supported.
# behaviors are tested so I know if any of it breaks, but unsupported behavior may change at any time.

describe 'unsupported behavior' do
  let(:schema_opt) { {} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07, **schema_opt) }
  let(:instance) { {} }
  let(:subject_opt) { {} }
  let(:subject) { schema.new_jsi(instance, **subject_opt) }

  describe 'JSI::Schema' do
    # reinstantiating objects at unrecognized paths as schemas is implemented but I don't want to officially
    # support it. the spec states that the behavior is undefined, and the code implementing it is brittle,
    # ugly, and prone to breakage, particularly with $id.
    describe 'reinstantiation' do
      describe 'below another schema' do
        let(:schema_content) do
          YAML.safe_load(<<~YAML
            definitions:
              a:
                $id: http://jsi/test/reinstantiation/below_another/a
                definitions:
                  sub:
                    {}
                unknown:
                  definitions:
                    b:
                      additionalProperties:
                        $ref: "#/definitions/sub"
            items:
              $ref: "#/definitions/a/unknown/definitions/b"
            YAML
          )
        end
        let(:instance) do
          [{'x' => {}}]
        end
        it "instantiates" do
          assert_equal(
            [JSI::Ptr["definitions", "a", "unknown", "definitions", "b"]],
            subject[0].jsi_schemas.map(&:jsi_ptr)
          )
          assert_equal(
            [JSI::Ptr["definitions", "a", "definitions", "sub"]],
            subject[0]['x'].jsi_schemas.map(&:jsi_ptr)
          )
        end
      end

      describe("in a location described by the metaschema as a nonschema") do
        let(:schema_content) do
          YAML.safe_load(<<~YAML
            const: true
            properties:
              additionalProperties:
                $ref: "#/const"
            items:
              $ref: "#/properties"
            YAML
          )
        end
        let(:instance) do
          [{'x' => {}}]
        end

        it("instantiates") do
          assert_equal(
            [JSI::Ptr["properties"]],
            subject[0].jsi_schemas.map(&:jsi_ptr)
          )
          # the schema that describes subject[0] is both a schema and a 'properties' object
          assert_schemas(
            [
              JSI::JSONSchemaDraft07.schema,
              JSI::JSONSchemaDraft07.schema.properties['properties'],
            ],
            subject[0].jsi_schemas.first
          )
          assert_equal(
            [JSI::Ptr["const"]],
            subject[0]['x'].jsi_schemas.map(&:jsi_ptr)
          )
          # the schema that describes subject[0]['x'] is both a schema and a 'const' value
          assert_schemas(
            [
              JSI::JSONSchemaDraft07.schema,
              JSI::JSONSchemaDraft07.schema.properties['const'],
            ],
            subject[0]['x'].jsi_schemas.first
          )
        end
      end

      describe 'below nonschema root' do
        it "instantiates" do
          schema_doc_schema = JSI::JSONSchemaDraft04.new_schema({
            'properties' => {'schema' => {'$ref' => 'http://json-schema.org/draft-04/schema'}}
          })
          schema_doc = schema_doc_schema.new_jsi({
            'schema' => {'$ref' => '#/unknown'},
            'unknown' => {},
          })
          subject = schema_doc.schema.new_jsi({})
          assert_equal(
            [JSI::Ptr["unknown"]],
            subject.jsi_schemas.map(&:jsi_ptr)
          )
        end
      end
      describe 'the origin schema has schemas that do not describe a schema (items)' do
        let(:schema_content) do
          {
            'items' => {'$ref' => '#/unknown'},
            'unknown' => {},
          }
        end
        let(:instance) do
          [{}]
        end
        it "instantiates" do
          assert_equal(
            [JSI::Ptr["unknown"]],
            subject[0].jsi_schemas.map(&:jsi_ptr)
          )
          unknown_schema = subject[0].jsi_schemas.to_a[0]
          # check it's not an items schema like schema.items is
          assert_equal(schema.jsi_schemas, unknown_schema.jsi_schemas)
          refute_equal(schema.items.jsi_schemas, unknown_schema.jsi_schemas)
        end
      end
    end
  end

  describe("cyclical $ref application") do
    describe("self-referential") do
      let(:schema_content) do
        {
          '$ref' => '#',
        }
      end

      it("raises ResolutionError") do
        assert_raises(JSI::ResolutionError) { subject }
        assert_raises(JSI::ResolutionError) { schema.instance_validate(instance) }
      end
    end

    describe("mutually self-referential") do
      let(:schema_content) do
        {
          'definitions' => {
            'alice' => {
              '$ref' => '#/definitions/bob',
            },
            'bob' => {
              '$ref' => '#/definitions/alice',
            },
          },
          'allOf' => [{'$ref' => '#/definitions/alice'}, {'$ref' => '#/definitions/bob'}],
        }
      end

      it("raises ResolutionError") do
        assert_raises(JSI::ResolutionError) { subject }
        assert_raises(JSI::ResolutionError) { schema.instance_validate(instance) }
      end
    end
  end

  describe 'property names which are not strings' do
    ARBITRARY_OBJECT = Object.new
    describe 'arbitrary object property name' do
      let(:schema_content) do
        {
          'properties' => {
            ARBITRARY_OBJECT => {'type' => 'string'},
          },
        }
      end
      let(:schema_opt) { {to_immutable: nil} }
      let(:instance) do
        {
          ARBITRARY_OBJECT => {},
        }
      end
      let(:subject_opt) { {to_immutable: nil} }

      it 'applies properties' do
        assert_schemas([schema.properties[ARBITRARY_OBJECT]], subject[ARBITRARY_OBJECT])
        assert(!subject.jsi_valid?)
        assert(!subject[ARBITRARY_OBJECT].jsi_valid?)
      end
    end
    describe 'property name which is an array, described by propertyNames' do
      let(:schema_content) do
        {
          'properties' => {
            [1] => {},
          },
          'propertyNames' => {
            'type' => 'array',
            'items' => {'type' => 'integer'},
          },
        }
      end
      describe 'valid' do
        let(:instance) do
          {
            [] => {},
            [1] => {},
          }
        end

        it 'applies properties, propertyNames' do
          assert_schemas([schema.properties[[1]]], subject[[1]])
          assert_schemas([], subject[[]])

          assert(subject.jsi_valid?)

          subject.jsi_each_propertyName do |propertyName|
            assert_schemas([schema.propertyNames], propertyName)
          end
          # child application of propertyNames' `items` subschema
          pn_item = subject.jsi_each_propertyName.detect { |j| j.size > 0 }[0, as_jsi: true]
          assert_schemas([schema.propertyNames.items], pn_item)

          assert(subject.jsi_each_propertyName.to_a.all?(&:jsi_valid?))

          exp_jsis = [schema.propertyNames.new_jsi([]), schema.propertyNames.new_jsi([1])]
          assert_equal(exp_jsis, subject.jsi_each_propertyName.to_a) # this test seems unnecessary, w/e
        end
      end
      describe 'invalid' do
        let(:instance) do
          {
            [] => {},
            [1] => {},
            {} => {},
          }
        end

        it 'applies properties, propertyNames' do
          assert_schemas([schema.properties[[1]]], subject[[1]])
          assert_schemas([], subject[[]])

          assert_equal([
            "instance type does not match `type` value",
            "instance object property names are not all valid against `propertyNames` schema",
          ], subject.jsi_validate.each_validation_error.map(&:message))

          subject.jsi_each_propertyName do |propertyName|
            assert_schemas([schema.propertyNames], propertyName)
          end

          valid, invalid = subject.jsi_each_propertyName.partition(&:jsi_valid?)
          assert_equal([[], [1]], valid.map(&:jsi_instance))
          assert_equal([{}], invalid.map(&:jsi_instance))
        end
      end
    end

    describe '#jsi_each_descendent_node(propertyNames: true)' do
      DescPropNamesTest = JSI::JSONSchemaDraft07.new_schema_module({
        'patternProperties' => {
          '^n' => {'title' => 'no'}, # 'no' properties don't recurse
        },
        'additionalProperties' => {'$ref' => '#'}, # other properties do
        'propertyNames' => {
          'items' => [{}], # first item doesn't recurse
          'additionalItems' => {'$ref' => '#'}, # rest of items do
        }
      })

      let(:schema) do
        DescPropNamesTest.schema
      end

      let(:yesno_object) { {'y' => {'a' => 0}, 'n' => {'a' => 0}} }
      let(:ary01) { [yesno_object, yesno_object] }
      let(:instance) do
        {
          ary01 => yesno_object,
          'no' => ary01,
        }
      end

      it "yields descendent JSIs and propertyNames" do
        expected_nodes = Set[]
        expected_nodes << subject
        subject_key_ary01 = schema.propertyNames.new_jsi(ary01)
        expected_nodes += [ # recursing the first propertyName
          subject_key_ary01,
          subject_key_ary01 / [0],
          JSI::SchemaSet[].new_jsi('y'), # (subject key ary01) / [0] key 'y'
          JSI::SchemaSet[].new_jsi('n'), # (subject key ary01) / [0] key 'n'
          subject_key_ary01 / [0, 'y'],
          JSI::SchemaSet[].new_jsi('a'), # (subject key ary01) / [0, 'y'] key 'a'
          subject_key_ary01 / [0, 'y', 'a'],
          subject_key_ary01 / [0, 'n'],
          JSI::SchemaSet[].new_jsi('a'), # (subject key ary01) / [0, 'n'] key 'a'
          subject_key_ary01 / [0, 'n', 'a'],
          subject_key_ary01 / [1],
          schema.propertyNames.new_jsi('y'), # (subject key ary01) / [1] key 'y'
          schema.propertyNames.new_jsi('n'), # (subject key ary01) / [1] key 'n'
          subject_key_ary01 / [1, 'y'],
          schema.propertyNames.new_jsi('a'), # (subject key ary01) / [1, 'y'] key 'a'
          subject_key_ary01 / [1, 'y', 'a'],
          subject_key_ary01 / [1, 'n'],
          JSI::SchemaSet[].new_jsi('a'), # (subject key ary01) / [1, 'n'] key 'a'
          subject_key_ary01 / [1, 'n', 'a'],
        ]
        expected_nodes << schema.propertyNames.new_jsi('no') # second propertyName (nothing to recurse)
        expected_nodes += [ # recursing the first property value
          subject / [ary01],
          schema.propertyNames.new_jsi('y'), # subject / [ary01] key 'y'
          schema.propertyNames.new_jsi('n'), # subject / [ary01] key 'n'
          subject / [ary01, 'y'],
          schema.propertyNames.new_jsi('a'), # subject / [ary01, 'y'] key 'a'
          subject / [ary01, 'y', 'a'],
          subject / [ary01, 'n'],
          JSI::SchemaSet[].new_jsi('a'), # subject / [ary01, 'n'] key 'a'
          subject / [ary01, 'n', 'a'],
        ]
        expected_nodes += [ # recursing the second property value
          subject / ['no'],
          subject / ['no', 0],
          JSI::SchemaSet[].new_jsi('y'), # subject / ['no', 0] key 'y'
          JSI::SchemaSet[].new_jsi('n'), # subject / ['no', 0] key 'n'
          subject / ['no', 0, 'y'],
          JSI::SchemaSet[].new_jsi('a'), # subject / ['no', 0, 'y'] key 'a'
          subject / ['no', 0, 'y', 'a'],
          subject / ['no', 0, 'n'],
          JSI::SchemaSet[].new_jsi('a'), # subject / ['no', 0, 'n'] key 'a'
          subject / ['no', 0, 'n', 'a'],
          subject / ['no', 1],
          JSI::SchemaSet[].new_jsi('y'), # subject / ['no', 1] key 'y'
          JSI::SchemaSet[].new_jsi('n'), # subject / ['no', 1] key 'n'
          subject / ['no', 1, 'y'],
          JSI::SchemaSet[].new_jsi('a'), # subject / ['no', 1, 'y'] key 'a'
          subject / ['no', 1, 'y', 'a'],
          subject / ['no', 1, 'n'],
          JSI::SchemaSet[].new_jsi('a'), # subject / ['no', 1, 'n'] key 'a'
          subject / ['no', 1, 'n', 'a'],
        ]
        assert_equal(expected_nodes, subject.jsi_each_descendent_node(propertyNames: true).to_set)
      end
    end
  end

  describe 'an instance that responds to to_hash and to_ary' do
    class HashlikeAry
      def initialize(ary)
        @ary = ary
      end

      def to_hash
        @ary.each_with_index.map { |e, i| {i => e} }.inject({}, &:update)
      end

      def to_ary
        @ary
      end

      def each_index(&b)
        @ary.each_index(&b)
      end

      def keys
        @ary.each_index.to_a
      end

      def each_key(&b)
        @ary.each_index(&b)
      end
    end

    let(:subject_opt) { {to_immutable: nil} }

    describe 'properties and items' do
      let(:schema_content) do
        {
          'properties' => {
            0 => {},
          },
          'items' => {
          },
        }
      end
      let(:instance) do
        HashlikeAry.new([{}])
      end

      it 'applies properties and items' do
        assert_schemas([schema.properties[0], schema.items], subject[0])
        assert_is_a(Hash, subject.to_hash)
        assert_is_a(Array, subject.to_ary)
      end
    end

    describe 'additionalProperties, patternProperties, additionalItems' do
      let(:schema_content) do
        {
          'properties' => {
            0 => {},
          },
          'patternProperties' => {
            '1' => {}
          },
          'additionalProperties' => {},
          'items' => [
            {},
          ],
          'additionalItems' => {},
        }
      end

      let(:instance) do
        HashlikeAry.new([{}, {}, {}])
      end

      it 'applies' do
        assert_schemas([schema.properties[0],         schema.items[0]],        subject[0])
        assert_schemas([schema.patternProperties['1'], schema.additionalItems], subject[1])
        assert_schemas([schema.additionalProperties,  schema.additionalItems], subject[2])
        assert(subject.jsi_valid?)
        assert_is_a(Hash, subject.to_hash)
        assert_is_a(Array, subject.to_ary)
      end
    end
  end

  describe 'recursive structures' do
    describe 'a instance whose child references itself' do
      let(:schema_content) do
        YAML.load(<<~YAML
          properties:
            "a": {}
            "on":
              $ref: "#"
          YAML
        )
      end
      it 'goes all the way down' do
        child = {'a' => ['turtle']}
        child['on'] = child
        root = {'a' => ['world'], 'on' => child}
        jsi = schema.new_jsi(root, to_immutable: nil)
        assert_schemas([schema.properties['a']], jsi.a)
        assert_schemas([schema], jsi.on)
        # little deeper
        deep_parent_ptr = JSI::Ptr['on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on']
        assert_schemas([schema.properties['a']], deep_parent_ptr.evaluate(jsi).a)
        assert_schemas([schema], deep_parent_ptr.evaluate(jsi))

        # lul
        #assert_raises(SystemStackError) do
        #  jsi.jsi_each_descendent_node { }
        #end
      end
    end
  end

  describe 'conflicting JSI Schema Module instance methods' do
    let(:schema_content) do
      YAML.safe_load(<<~YAML
        definitions:
          a:
            {}
          b:
            {}
        allOf:
          - $ref: "#/definitions/a"
          - $ref: "#/definitions/b"
        YAML
      )
    end
    let(:instance) do
      {}
    end
    it "defines both; an undefined one wins" do
      schema.definitions['a'].jsi_schema_module_exec { define_method(:foo) { :a } }
      schema.definitions['b'].jsi_schema_module_exec { define_method(:foo) { :b } }
      assert_includes([:a, :b], subject.foo)
    end
  end
end

$test_report_file_loaded[__FILE__]
