require_relative 'test_helper'

BASIC_DIALECT = JSI::Schema::Dialect.new(
  vocabularies: [
    JSI::Schema::Vocabulary.new(elements: [
      JSI::Schema::Elements::ID[keyword: '$id', fragment_is_anchor: false],
      JSI::Schema::Elements::REF[exclusive: true],
      JSI::Schema::Elements::SELF[],
      JSI::Schema::Elements::PROPERTIES[],
    ]),
  ],
)

BasicMetaSchema = JSI.new_metaschema_module(
  YAML.load(<<~YAML
    "$id": "tag:named-basic-meta-schema"
    properties:
      properties:
        additionalProperties:
          "$ref": "#"
      additionalProperties:
        "$ref": "#"
      "$ref": {}
    YAML
  ),
  dialect: BASIC_DIALECT,
)

describe(JSI::MetaSchemaNode) do
  let(:dialect) { BASIC_DIALECT }
  let(:metaschema_root_ref) { '#' }
  let(:root_schema_ref) { metaschema_root_ref }
  let(:registry) { nil }
  let(:bootstrap_registry) { nil }
  let(:to_immutable) { JSI::DEFAULT_CONTENT_TO_IMMUTABLE }

  let(:root_node) do
    JSI::MetaSchemaNode.new(to_immutable[metaschema_document],
      msn_dialect: dialect,
      metaschema_root_ref: metaschema_root_ref,
      root_schema_ref: root_schema_ref,
      jsi_registry: registry,
      bootstrap_registry: bootstrap_registry,
      jsi_content_to_immutable: to_immutable,
    )
  end
  let(:metaschema) do
    metaschema_root_ref = JSI::Util.uri(self.metaschema_root_ref)
    if metaschema_root_ref.merge(fragment: nil).empty?
      root_node.jsi_descendent_node(JSI::Ptr.from_fragment(metaschema_root_ref.fragment))
    else
      root_node
      JSI::Schema::Ref.new(metaschema_root_ref, registry: registry).resolve
    end
  end

  def bootstrap_schema(schema_content, registry: nil, base_uri: nil)
    dialect.bootstrap_schema(
      schema_content,
      jsi_schema_base_uri: JSI::Util.uri(base_uri, nnil: false),
      jsi_registry: registry,
    )
  end

  def assert_metaschema_behaves
    assert_schemas([metaschema], metaschema)
    assert_schemas([metaschema.properties['properties']], metaschema.properties)
    assert_schemas([metaschema], metaschema.properties['properties'])
    assert_schemas([metaschema], metaschema.properties['properties'].additionalProperties)

    schema = metaschema.new_schema({
      'properties' => {
        'foo' => {},
      },
      'additionalProperties' => {},
    })
    assert_schemas([metaschema], schema)
    assert_is_a(JSI::Schema, schema)
    assert_schemas([metaschema.properties['properties']], schema.properties)
    assert_schemas([metaschema], schema.properties['foo'])
    assert_is_a(JSI::Schema, schema.properties['foo'])
    assert_schemas([metaschema], schema.additionalProperties)
    assert_is_a(JSI::Schema, schema.additionalProperties)

    instance = schema.new_jsi({'foo' => [], 'bar' => []})
    assert_schemas([schema], instance)
    assert_schemas([schema.properties['foo']], instance.foo)
    assert_schemas([schema.additionalProperties], instance['bar'])

    # check that subscripting unknown keys behaves
    assert_equal(nil, metaschema['no'])
    assert_equal(nil, metaschema.properties['no'])

    # a metaschema validates itself
    assert(metaschema.jsi_valid?)
    assert(metaschema.instance_valid?(metaschema))
  end

  describe 'basic' do
    let(:metaschema_document) do
      YAML.load(<<~YAML
        properties:
          properties:
            additionalProperties:
              "$ref": "#"
          additionalProperties:
            "$ref": "#"
          "$ref": {}
        YAML
      )
    end

    it('acts like a meta-schema') do
      assert_metaschema_behaves
    end
    it 'is pretty' do
      inspect = %q(#{<JSI:MSN (#) Meta-Schema> "properties" => #{<JSI:MSN*1> "properties" => #{<JSI:MSN (#) Schema> "additionalProperties" => #{<JSI:MSN (#) Schema> "$ref" => "#"}}, "additionalProperties" => #{<JSI:MSN (#) Schema> "$ref" => "#"}, "$ref" => #{<JSI:MSN (#) Schema>}}})
      assert_equal(inspect, metaschema.inspect)
      assert_equal(inspect, metaschema.to_s)
      pp = <<~PP
        \#{<JSI:MSN (#) Meta-Schema>
          "properties" => \#{<JSI:MSN*1>
            "properties" => \#{<JSI:MSN (#) Schema>
              "additionalProperties" => \#{<JSI:MSN (#) Schema> "$ref" => "#"}
            },
            "additionalProperties" => \#{<JSI:MSN (#) Schema> "$ref" => "#"},
            "$ref" => \#{<JSI:MSN (#) Schema>}
          }
        }
        PP
      assert_equal(pp, metaschema.pretty_inspect)
    end
  end

  describe 'basic, named' do
    it 'is pretty' do
      pretty = <<~str
      \#{<JSI:MSN (BasicMetaSchema) Meta-Schema>
        "$id" => "tag:named-basic-meta-schema",
        "properties" => \#{<JSI:MSN (BasicMetaSchema.properties["properties"])>
          "properties" => \#{<JSI:MSN (BasicMetaSchema) Schema>
            "additionalProperties" => \#{<JSI:MSN (BasicMetaSchema) Schema>
              "$ref" => "#"
            }
          },
          "additionalProperties" => \#{<JSI:MSN (BasicMetaSchema) Schema>
            "$ref" => "#"
          },
          "$ref" => \#{<JSI:MSN (BasicMetaSchema) Schema>}
        }
      }
      str
      assert_equal(pretty, BasicMetaSchema.schema.pretty_inspect)
    end

    it("descendents have ids") do
      uris = BasicMetaSchema.schema.properties['properties'].additionalProperties.schema_uris
      assert_uris(['tag:named-basic-meta-schema#/properties/properties/additionalProperties'], uris)
    end
  end

  describe("multi document meta-schema") do
    describe("two documents") do
      let(:dialect) do
        JSI::Schema::Dialect.new(
          vocabularies: [
            JSI::Schema::Vocabulary.new(elements: [
              JSI::Schema::Elements::SELF[],
              JSI::Schema::Elements::ID[keyword: '$id', fragment_is_anchor: false],
              JSI::Schema::Elements::REF[exclusive: true],
              JSI::Schema::Elements::PROPERTIES[], # note: element supports patternProperties but meta-schema does not
              JSI::Schema::Elements::ITEMS[], # note: element supports additionalItems but meta-schema does not
              JSI::Schema::Elements::ALL_OF[],
            ]),
          ],
        )
      end

      let(:metaschema_document) do
        to_immutable[YAML.load(<<~YAML
          $id: "tag:7bg7:meta"
          allOf:
            - "$ref": "tag:7bg7:applicator"
          properties:
            "$id": {}
            "$ref": {}
          YAML
        )]
      end

      let(:applicator_document) do
        to_immutable[YAML.load(<<~YAML
          $id: "tag:7bg7:applicator"
          properties:
            properties:
              additionalProperties:
                "$ref": "tag:7bg7:meta"
            additionalProperties:
              "$ref": "tag:7bg7:meta"
            items:
              "$ref": "tag:7bg7:meta"
            allOf:
              items:
                "$ref": "tag:7bg7:meta"
          YAML
        )]
      end

      let(:metaschema_root_ref) { "tag:7bg7:meta" }

      let(:registry) do
        JSI::Registry.new
      end

      let(:bootstrap_registry) do
        registry = JSI::Registry.new
        registry.register(bootstrap_schema(metaschema_document, registry: registry))
        registry.register(bootstrap_schema(applicator_document, registry: registry))
        registry
      end

      let(:applicator_schema) do
        metaschema
        registry.find("tag:7bg7:applicator")
      end

      it("acts like a meta-schema") do
        assert_schemas([metaschema, applicator_schema], metaschema)
        assert_schemas([metaschema.properties['$id']],  metaschema / ['$id'])
        assert_schemas([applicator_schema.properties['allOf']],
                                                        metaschema / ['allOf'])
        assert_schemas([metaschema, applicator_schema], metaschema / ['allOf', 0])
        assert_schemas([metaschema.properties['$ref']], metaschema / ['allOf', 0, '$ref'])
        assert_schemas([applicator_schema.properties['properties']],
                                                        metaschema / ['properties'])
        assert_schemas([metaschema, applicator_schema], metaschema / ['properties', '$id'])
        assert_schemas([metaschema, applicator_schema], metaschema / ['properties', '$ref'])
        assert_schemas([metaschema, applicator_schema], applicator_schema)
        assert_schemas([metaschema.properties['$id']],  applicator_schema / ['$id'])
        assert_schemas([applicator_schema.properties['properties']],
                                                        applicator_schema / ['properties'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'properties'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'properties', 'additionalProperties'])
        assert_schemas([metaschema.properties['$ref']], applicator_schema / ['properties', 'properties', 'additionalProperties', '$ref'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'additionalProperties'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'items'])
        assert_schemas([metaschema.properties['$ref']], applicator_schema / ['properties', 'items', '$ref'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'allOf'])
        assert_schemas([metaschema, applicator_schema], applicator_schema / ['properties', 'allOf', 'items'])
        assert_schemas([metaschema.properties['$ref']], applicator_schema / ['properties', 'allOf', 'items', '$ref'])

        # subscripting keys that are not present
        assert_equal(nil, metaschema['no'])
        assert_equal(nil, metaschema.properties['no'])

        # validates the schemas of the meta-schema
        assert(metaschema.jsi_valid?)
        assert(applicator_schema.jsi_valid?)
        assert(metaschema.instance_valid?(metaschema))
        assert(metaschema.instance_valid?(applicator_schema))


        schema = metaschema.new_schema({
          'properties' => {
            'foo' => {
              '$id' => 'tag:55ky',
              'items' => {},
            },
          },
          'additionalProperties' => {
            '$ref' => '#',
          },
          'allOf' => [
            {
              'properties' => {
                'bar' => {},
              },
            },
          ],
        })
        assert_schemas([metaschema, applicator_schema],              schema)
        assert_schemas([applicator_schema.properties['properties']], schema / ["properties"])
        assert_schemas([metaschema, applicator_schema],              schema / ["properties", "foo"])
        assert_schemas([metaschema.properties['$id']],               schema / ["properties", "foo", "$id"])
        assert_schemas([metaschema, applicator_schema],              schema / ["properties", "foo", "items"])
        assert_schemas([metaschema, applicator_schema],              schema / ["additionalProperties"])
        assert_schemas([metaschema.properties['$ref']],              schema / ["additionalProperties", "$ref"])
        assert_schemas([applicator_schema.properties['allOf']],      schema / ["allOf"])
        assert_schemas([metaschema, applicator_schema],              schema / ["allOf", 0])
        assert_schemas([applicator_schema.properties['properties']], schema / ["allOf", 0, "properties"])
        assert_schemas([metaschema, applicator_schema],              schema / ["allOf", 0, "properties", "bar"])

        assert(schema.jsi_valid?)
        assert(metaschema.instance_valid?(schema))

        [metaschema, applicator_schema, schema].each do |jsi|
          jsi.jsi_each_descendent_node do |node|
            assert_equal(node.equal?(metaschema), node.is_a?(JSI::Schema::MetaSchema))
            assert_equal(node.jsi_schemas == Set[metaschema, applicator_schema], node.is_a?(JSI::Schema))
          end
        end


        schema_by_uri = JSI.new_schema(
          {"$schema" => "tag:7bg7:meta"},
          registry: registry,
        )
        assert_schemas([metaschema, applicator_schema], schema_by_uri)


        instance = schema.new_jsi({'foo' => [], 'bar' => []})
        assert_schemas([schema, schema.allOf[0]], instance)
        assert_schemas([schema.properties['foo']], instance.foo)
        assert_schemas([schema.allOf[0].properties['bar'], schema, schema.allOf[0]], instance['bar'])
        assert(instance.jsi_valid?)
      end
    end
  end

  describe 'with schema default' do
    let(:metaschema_document) do
      YAML.load(<<~YAML
        properties:
          properties:
            additionalProperties:
              "$ref": "#"
          additionalProperties:
            "$ref": "#"
          "$ref": {}
          default:
            default:
              default
        default: {}
        YAML
      )
    end

    it 'does not insert a default value' do
      metaschema.jsi_schema_module_exec { define_method(:jsi_child_use_default_default) { true } }

      assert_nil(metaschema.additionalProperties)
      assert_nil(metaschema.properties['additionalProperties'].default)
      assert_nil(metaschema.properties['additionalProperties'].default(as_jsi: true))
    end
  end

  describe 'json schema draft' do
    it 'type has a schema' do
      assert(JSI::JSONSchemaDraft06.schema.type.jsi_schemas.any?)
    end
    describe '#jsi_schemas' do
      let(:metaschema) { JSI::JSONSchemaDraft06.schema }
      it 'has jsi_schemas' do
        assert_schemas([metaschema], metaschema)
        assert_schemas([metaschema.properties['properties']], metaschema.properties)
      end
    end
  end

  describe("draft04 boolean schema in meta-schema") do
    it("is a schema") do
      # d4 meta-schema doesn't have any boolean schema in it; make one that does
      d4ms_with_bool = JSI.new_metaschema(
        JSON.parse(JSI::SCHEMAS_PATH.join('json-schema.org/draft-04/schema.json').read).merge({
          'additionalProperties' => true,
        }),
        dialect: JSI::Schema::Draft04::DIALECT,
      )
      # note: this still breaks if d4ms_with_bool.additionalProperties is accessed, i.e. computes its schemas,
      # before the following line makes its schema describes_schema!
      d4ms_with_bool["properties"]["additionalProperties"]["anyOf"][0].describes_schema!(JSI::Schema::Draft04::DIALECT)
      d4ms_with_bool["properties"]["additionalItems"]["anyOf"][0].describes_schema!(JSI::Schema::Draft04::DIALECT)

      # check that, for an instance of that meta-schema, a node described by additionalProperties is correctly instantiated
      j = d4ms_with_bool.new_jsi({'x' => {}})
      assert_schemas([d4ms_with_bool.additionalProperties], j['x'])

      # this would fail previously because d4ms_with_bool.additionalProperties never had
      # Schema#jsi_schema_initialize called, because it was extended with Schema via
      # d4ms_with_bool["properties"]["additionalProperties"]["anyOf"][0].jsi_schema_module,
      # not Schema itself. fixed by making modules that include Schema define .extended to call jsi_schema_initialize.
    end
  end

  describe('meta-schema outside the root, document is an instance of a schema in the document') do
    let(:metaschema_document) do
      YAML.load(<<~YAML
        schemas:
          JsonSchema:
            id: JsonSchema
            properties:
              additionalProperties:
                "$ref": JsonSchema
              properties:
                additionalProperties:
                  "$ref": JsonSchema
          Document:
            id: Document
            type: object
            properties:
              schemas:
                type: object
                additionalProperties:
                  "$ref": JsonSchema
        YAML
      )
    end
    let(:metaschema_root_ref) { '#/schemas/JsonSchema' }
    let(:root_schema_ref) { '#/schemas/Document' }
    it('acts like a meta-schema') do
      assert_schemas([root_node.schemas['Document']], root_node)
      assert_schemas([root_node.schemas['Document'].properties['schemas']], root_node.schemas)
      assert_schemas([metaschema], root_node.schemas['Document'])
      assert_schemas([metaschema.properties['properties']], root_node.schemas['Document'].properties)
      assert_schemas([metaschema], root_node.schemas['Document'].properties['schemas'])

      assert_metaschema_behaves
    end
  end
  describe('meta-schema outside the root, document is a schema') do
    let(:metaschema_document) do
      YAML.load(<<~YAML
        $defs:
          JsonSchema:
            properties:
              additionalProperties:
                "$ref": "#/$defs/JsonSchema"
              properties:
                additionalProperties:
                  "$ref": "#/$defs/JsonSchema"
              $defs:
                additionalProperties:
                  "$ref": "#/$defs/JsonSchema"
        YAML
      )
    end
    let(:metaschema_root_ref) { '#/$defs/JsonSchema' }
    it('acts like a meta-schema') do
      assert_schemas([metaschema], root_node)
      assert_schemas([metaschema.properties['$defs']], root_node['$defs'])

      assert_metaschema_behaves
    end
  end
  describe('meta-schema outside the root on schemas, document is a schema') do
    let(:metaschema_document) do
      YAML.load(<<~YAML
        schemas:
          JsonSchema:
            id: JsonSchema
            properties:
              additionalProperties:
                "$ref": JsonSchema
              properties:
                additionalProperties:
                  "$ref": JsonSchema
              schemas:
                additionalProperties:
                  "$ref": JsonSchema
        YAML
      )
    end
    let(:metaschema_root_ref) { '#/schemas/JsonSchema' }
    it('acts like a meta-schema') do
      assert_schemas([metaschema], root_node)
      assert_schemas([metaschema.properties['schemas']], root_node.schemas)

      assert_metaschema_behaves
    end
  end

  describe('#jsi_modified_copy') do
    let(:metaschema) { BasicMetaSchema.schema }
    it('modifies a copy') do
      # at the root
      mc1 = metaschema.merge('title' => 'root modified')
      assert_equal('root modified', mc1['title'])
      refute_equal(metaschema, mc1)
      assert_equal(metaschema.jsi_document.merge('title' => 'root modified'), mc1.jsi_document)
      # below the root
      mc2 = metaschema.properties.merge('foo' => [])
      assert_equal([], mc2['foo', as_jsi: false])
      mc2root = mc2.jsi_root_node
      refute_equal(metaschema, mc2root)
      expected_mc2_document = metaschema.jsi_document.merge('properties' => metaschema.jsi_document['properties'].merge('foo' => []))
      assert_equal(expected_mc2_document, mc2.jsi_document)
    end
  end

  metaschema_modules = [
    JSI::JSONSchemaDraft04,
    JSI::JSONSchemaDraft06,
    JSI::JSONSchemaDraft07,
  ]
  metaschema_modules.each do |metaschema_module|
    describe(metaschema_module.name) do
      let(:metaschema) { metaschema_module.schema }

      it 'validates itself' do
        assert(metaschema.jsi_valid?)
        assert(metaschema.instance_valid?(metaschema))
        assert(metaschema.jsi_each_descendent_node.all?(&:jsi_valid?))
      end
    end
  end

  describe('a meta-schema fails to validate itself') do
    let(:metaschema) { JSI::JSONSchemaDraft06.schema.merge({'title' => []}) }

    it 'has validation error for `title`' do
      results = [
        metaschema.jsi_validate,
        metaschema.instance_validate(metaschema),
      ]
      metaschema.jsi_each_descendent_node do |node|
        if node.jsi_ptr.ancestor_of?(JSI::Ptr['title'])
          results << node.jsi_validate
        else
          assert(node.jsi_valid?)
        end
      end
      results.each do |result|
        assert_includes(result.each_validation_error.map(&:keyword), 'type')
      end
    end
  end

  describe('meta-schema subschema modules') do
    # sanity check that meta-schemas' named subschema modules are actually subschemas of the meta-schema
    def check_consts(metaschema, mod)
      assert_is_a(JSI::SchemaModule, mod)
      assert_equal(metaschema, mod.schema.jsi_root_node)
      mod.constants.each do |const_name|
        const = mod.const_get(const_name)
        next unless const.is_a?(Module) && const.name.start_with?(mod.name)
        check_consts(metaschema, const)
      end
    end

    it 'named constants are subschema modules' do
      [JSI::JSONSchemaDraft04, JSI::JSONSchemaDraft06, JSI::JSONSchemaDraft07].each do |metaschema_module|
        check_consts(metaschema_module.schema, metaschema_module)
      end
    end
  end
end

$test_report_file_loaded[__FILE__]
