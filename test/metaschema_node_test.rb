require_relative 'test_helper'

BasicMetaschema = JSI.new_metaschema_module(
  YAML.load(<<~YAML
    "$id": "tag:named-basic-metaschema"
    properties:
      properties:
        additionalProperties:
          "$ref": "#"
      additionalProperties:
        "$ref": "#"
      "$ref": {}
    YAML
  ),
  schema_implementation_modules: [JSI::Schema::Application::Draft06],
)

describe JSI::MetaschemaNode do
  let(:schema_implementation_modules) do
    [
      JSI::Schema::Application::Draft06,
    ]
  end

  let(:metaschema_root_ptr) { JSI::Ptr[] }
  let(:root_schema_ptr) { JSI::Ptr[] }

  let(:root_node) do
    JSI::MetaschemaNode.new(jsi_document,
      schema_implementation_modules: schema_implementation_modules,
      metaschema_root_ptr: metaschema_root_ptr,
      root_schema_ptr: root_schema_ptr,
    )
  end
  let(:metaschema) { root_node.jsi_descendent_node(metaschema_root_ptr) }

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
  end

  describe 'basic' do
    let(:jsi_document) do
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

    it 'acts like a metaschema' do
      assert_metaschema_behaves
    end
    it 'is pretty' do
      inspect = %q(#{<JSI::MetaschemaNode (#) Metaschema> "properties" => #{<JSI::MetaschemaNode (#/properties/properties)> "properties" => #{<JSI::MetaschemaNode (#) Schema> "additionalProperties" => #{<JSI::MetaschemaNode (#) Schema> "$ref" => "#"}}, "additionalProperties" => #{<JSI::MetaschemaNode (#) Schema> "$ref" => "#"}, "$ref" => #{<JSI::MetaschemaNode (#) Schema>}}})
      assert_equal(inspect, metaschema.inspect)
      assert_equal(inspect, metaschema.to_s)
      pp = <<~PP
        \#{<JSI::MetaschemaNode (#) Metaschema>
          "properties" => \#{<JSI::MetaschemaNode (#/properties/properties)>
            "properties" => \#{<JSI::MetaschemaNode (#) Schema>
              "additionalProperties" => \#{<JSI::MetaschemaNode (#) Schema>
                "$ref" => "#"
              }
            },
            "additionalProperties" => \#{<JSI::MetaschemaNode (#) Schema> "$ref" => "#"
            },
            "$ref" => \#{<JSI::MetaschemaNode (#) Schema>}
          }
        }
        PP
      assert_equal(pp, metaschema.pretty_inspect)
    end
  end

  describe 'basic, named' do
    it 'is pretty' do
      pretty = <<~str
      \#{<JSI::MetaschemaNode (BasicMetaschema) Metaschema>
        "$id" => "tag:named-basic-metaschema",
        "properties" => \#{<JSI::MetaschemaNode (BasicMetaschema.properties["properties"])>
          "properties" => \#{<JSI::MetaschemaNode (BasicMetaschema) Schema>
            "additionalProperties" => \#{<JSI::MetaschemaNode (BasicMetaschema) Schema>
              "$ref" => "#"
            }
          },
          "additionalProperties" => \#{<JSI::MetaschemaNode (BasicMetaschema) Schema>
            "$ref" => "#"
          },
          "$ref" => \#{<JSI::MetaschemaNode (BasicMetaschema) Schema>}
        }
      }
      str
      assert_equal(pretty, BasicMetaschema.schema.pretty_inspect)
    end
  end

  describe 'with schema default' do
    let(:jsi_document) do
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
  describe 'metaschema outside the root, document is an instance of a schema in the document' do
    let(:jsi_document) do
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
    let(:metaschema_root_ptr) { JSI::Ptr['schemas', 'JsonSchema'] }
    let(:root_schema_ptr) { JSI::Ptr['schemas', 'Document'] }
    it 'acts like a metaschema' do
      assert_schemas([root_node.schemas['Document']], root_node)
      assert_schemas([root_node.schemas['Document'].properties['schemas']], root_node.schemas)
      assert_schemas([metaschema], root_node.schemas['Document'])
      assert_schemas([metaschema.properties['properties']], root_node.schemas['Document'].properties)
      assert_schemas([metaschema], root_node.schemas['Document'].properties['schemas'])

      assert_metaschema_behaves
    end
  end
  describe 'metaschema outside the root, document is a schema' do
    let(:jsi_document) do
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
    let(:metaschema_root_ptr) { JSI::Ptr['$defs', 'JsonSchema'] }
    let(:root_schema_ptr) { JSI::Ptr['$defs', 'JsonSchema'] }
    it 'acts like a metaschema' do
      assert_schemas([metaschema], root_node)
      assert_schemas([metaschema.properties['$defs']], root_node['$defs'])

      assert_metaschema_behaves
    end
  end
  describe 'metaschema outside the root on schemas, document is a schema' do
    let(:jsi_document) do
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
    let(:metaschema_root_ptr) { JSI::Ptr['schemas', 'JsonSchema'] }
    let(:root_schema_ptr) { JSI::Ptr['schemas', 'JsonSchema'] }
    it 'acts like a metaschema' do
      assert_schemas([metaschema], root_node)
      assert_schemas([metaschema.properties['schemas']], root_node.schemas)

      assert_metaschema_behaves
    end
  end

  describe('#jsi_modified_copy') do
    let(:metaschema) { BasicMetaschema.schema }
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

  describe 'a metaschema fails to validate itself' do
    let(:metaschema) { JSI::JSONSchemaDraft06.schema.merge({'title' => []}) }

    it 'has validation error for `title`' do
      results = [
        metaschema.jsi_validate,
        metaschema.instance_validate(metaschema),
      ]
      metaschema.jsi_each_descendent_node do |node|
        if node.jsi_ptr.contains?(JSI::Ptr['title'])
          results << node.jsi_validate
        else
          assert(node.jsi_valid?)
        end
      end
      results.each do |result|
        assert_includes(result.validation_errors.map(&:keyword), 'type')
      end
    end
  end

  describe 'metaschema subschema modules' do
    # sanity check that metaschemas' named subschema modules are actually subschemas of the metaschema
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
