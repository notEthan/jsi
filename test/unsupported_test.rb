# frozen_string_literal: true

require_relative 'test_helper'

# the behavior described in these tests is not officially supported, but is not expected to break.

describe 'unsupported behavior' do
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }

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
      describe 'below nonschema root' do
        it "instantiates" do
          schema_doc_schema = JSI::JSONSchemaOrgDraft04.new_schema({
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
      let(:instance) do
        {
          ARBITRARY_OBJECT => {},
        }
      end

      it 'applies properties' do
        assert_is_a(schema.properties[ARBITRARY_OBJECT].jsi_schema_module, subject[ARBITRARY_OBJECT])
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
        it 'applies properties' do
          assert_is_a(schema.properties[[1]].jsi_schema_module, subject[[1]])
          assert_equal({}, subject[[]]) # not a jsi

          assert(subject.jsi_valid?)
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
        it 'applies properties' do
          assert_is_a(schema.properties[[1]].jsi_schema_module, subject[[1]])
          assert_equal({}, subject[[]]) # not a jsi

          assert_equal([
            "instance type does not match `type` value",
            "instance object property names are not all valid against `propertyNames` schema value",
          ], subject.jsi_validate.validation_errors.map(&:message))
        end
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

      it 'applies properties and itmes' do
        assert_is_a(schema.properties[0].jsi_schema_module, subject[0])
        assert_is_a(schema.items.jsi_schema_module, subject[0])
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
        assert_is_a(schema.properties[0].jsi_schema_module, subject[0])
        assert_is_a(schema.items[0].jsi_schema_module, subject[0])
        assert_is_a(schema.patternProperties['1'].jsi_schema_module, subject[1])
        assert_is_a(schema.additionalItems.jsi_schema_module, subject[1])
        assert_is_a(schema.additionalProperties.jsi_schema_module, subject[2])
        assert_is_a(schema.additionalItems.jsi_schema_module, subject[2])
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
        jsi = schema.new_jsi(root)
        assert_equal(Set[schema.properties['a']], jsi.a.jsi_schemas)
        assert_equal(Set[schema], jsi.on.jsi_schemas)
        # little deeper
        deep_parent_ptr = JSI::Ptr['on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on']
        assert_equal(Set[schema.properties['a']], deep_parent_ptr.evaluate(jsi).a.jsi_schemas)
        assert_equal(Set[schema], deep_parent_ptr.evaluate(jsi).jsi_schemas)

        # lul
        #assert_raises(SystemStackError) do
        #  jsi.jsi_each_child_node { }
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
      schema.definitions['a'].jsi_schema_module.module_eval { define_method(:foo) { :a } }
      schema.definitions['b'].jsi_schema_module.module_eval { define_method(:foo) { :b } }
      assert_includes([:a, :b], subject.foo)
    end
  end
end
