require_relative 'test_helper'

describe JSI::MetaschemaNode do
  let(:schema_implementation_modules) do
    [
      JSI::Schema,
      JSI::Schema::Application::Draft06,
    ]
  end
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
    let(:metaschema_root_ptr) { JSI::Ptr[] }
    let(:root_schema_ptr) { JSI::Ptr[] }
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
  describe 'json schema draft' do
    it 'type has a schema' do
      assert(JSI::JSONSchemaOrgDraft06.schema.type.jsi_schemas.any?)
    end
    describe '#jsi_schemas' do
      let(:metaschema) { JSI::JSONSchemaOrgDraft06.schema }
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
end
