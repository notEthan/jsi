require_relative 'test_helper'

describe JSI::MetaschemaNode do
  let(:metaschema_instance_modules) do
    [
      JSI::Schema,
      JSI::Schema::Application::Draft06,
    ]
  end
  let(:root_node) do
    JSI::MetaschemaNode.new(jsi_document,
      metaschema_instance_modules: metaschema_instance_modules,
      metaschema_root_ptr: metaschema_root_ptr,
      root_schema_ptr: root_schema_ptr,
    )
  end
  let(:metaschema) { metaschema_root_ptr.evaluate(root_node) }

  def assert_metaschema_behaves
    assert_is_a(metaschema.jsi_schema_module, metaschema)
    assert_is_a(metaschema.properties['properties'].jsi_schema_module, metaschema.properties)
    assert_is_a(metaschema.jsi_schema_module, metaschema.properties['properties'])
    assert_is_a(metaschema.jsi_schema_module, metaschema.properties['properties'].additionalProperties)

    schema = metaschema.new_schema({
      'properties' => {
        'foo' => {},
      },
      'additionalProperties' => {},
    })
    assert_is_a(metaschema.jsi_schema_module, schema)
    assert_is_a(JSI::Schema, schema)
    assert_is_a(metaschema.properties['properties'].jsi_schema_module, schema.properties)
    assert_is_a(metaschema.jsi_schema_module, schema.properties['foo'])
    assert_is_a(JSI::Schema, schema.properties['foo'])
    assert_is_a(metaschema.jsi_schema_module, schema.additionalProperties)
    assert_is_a(JSI::Schema, schema.additionalProperties)

    instance = schema.new_jsi({'foo' => [], 'bar' => []})
    assert_is_a(schema.jsi_schema_module, instance)
    assert_is_a(schema.properties['foo'].jsi_schema_module, instance.foo)
    assert_is_a(schema.additionalProperties.jsi_schema_module, instance['bar'])

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
        assert_equal(Set[metaschema], metaschema.jsi_schemas)
        assert_equal(Set[metaschema.properties['properties']], metaschema.properties.jsi_schemas)
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
      assert_is_a(root_node.schemas['Document'].jsi_schema_module, root_node)
      assert_is_a(root_node.schemas['Document'].properties['schemas'].jsi_schema_module, root_node.schemas)
      assert_is_a(metaschema.jsi_schema_module, root_node.schemas['Document'])
      assert_is_a(metaschema.properties['properties'].jsi_schema_module, root_node.schemas['Document'].properties)
      assert_is_a(metaschema.jsi_schema_module, root_node.schemas['Document'].properties['schemas'])

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
    let(:jsi_ptr) { JSI::Ptr[] }
    let(:metaschema_root_ptr) { JSI::Ptr['$defs', 'JsonSchema'] }
    let(:root_schema_ptr) { JSI::Ptr['$defs', 'JsonSchema'] }
    it 'acts like a metaschema' do
      assert_is_a(metaschema.jsi_schema_module, root_node)
      assert_is_a(metaschema.properties['$defs'].jsi_schema_module, root_node['$defs'])

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
    let(:jsi_ptr) { JSI::Ptr[] }
    let(:metaschema_root_ptr) { JSI::Ptr['schemas', 'JsonSchema'] }
    let(:root_schema_ptr) { JSI::Ptr['schemas', 'JsonSchema'] }
    it 'acts like a metaschema' do
      assert_is_a(metaschema.jsi_schema_module, root_node)
      assert_is_a(metaschema.properties['schemas'].jsi_schema_module, root_node.schemas)

      assert_metaschema_behaves
    end
  end
end
