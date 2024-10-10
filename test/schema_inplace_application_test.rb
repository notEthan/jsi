require_relative 'test_helper'

describe 'JSI Schema inplace application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe("#{name} in-place application aborted by $ref") do
      let(:metaschema) { metaschema }

      describe("any instance") do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              a: {}
            $ref: "#/definitions/a"
            dependencies: {a: {}}
            if: {}
            then: {}
            else: {}
            allOf: [{}]
            anyOf: [{}]
            oneOf: [{}]
            YAML
          )
        end
        let(:instance) { {"a" => {}, "b" => {}} }

        it("applies no $ref siblings") do
          assert_schemas([schema.definitions['a']], subject)
          refute_schema(schema.dependencies['a'], subject)
          refute_schema(schema['if'], subject) if schema['if'].jsi_is_schema?
          refute_schema(schema['then'], subject) if schema['then'].jsi_is_schema?
          refute_schema(schema['else'], subject) if schema['else'].jsi_is_schema?
          refute_schema(schema.allOf[0], subject)
          refute_schema(schema.anyOf[0], subject)
          refute_schema(schema.oneOf[0], subject)
        end
      end
    end
  end

  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe "#{name} inplace $ref application" do
      let(:metaschema) { metaschema }
      describe '$ref' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies $ref, excludes the schema containing $ref' do
          assert_schemas([
            schema.definitions['A'],
          ], subject)
          refute_is_a(schema.jsi_schema_module, subject)
        end
      end
      describe '$ref nested' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A:
                $ref: "#/definitions/B"
              B:
                {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies final $ref' do
          assert_schemas([
            schema.definitions['B'],
          ], subject)
          refute_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.definitions['A'].jsi_schema_module, subject)
        end
      end
      describe '$ref sibling applicators' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            allOf:
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'ignores' do
          assert_schemas([
            schema.definitions['A'],
          ], subject)
          refute_is_a(schema.jsi_schema_module, subject)
          refute_is_a(schema.allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'applicators through $ref target' do
        let(:schema_content) do
          YAML.load(<<~YAML
            definitions:
              A:
                allOf:
                  - {}
            $ref: "#/definitions/A"
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies' do
          assert_schemas([
            schema.definitions['A'],
            schema.definitions['A'].allOf[0],
          ], subject)
          refute_is_a(schema.jsi_schema_module, subject)
        end
      end
    end
  end
  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe "#{name} inplace allOf, anyOf, oneOf application" do
      let(:metaschema) { metaschema }
      describe 'allOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - {}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies' do
          assert_schemas([
            schema,
            schema.allOf[0],
            schema.allOf[1],
          ], subject)
        end
      end
      describe 'applicators through allOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - allOf:
                  - {}
              - oneOf:
                  - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies all' do
          assert_schemas([
            schema,
            schema.allOf[0],
            schema.allOf[0].allOf[0],
            schema.allOf[1],
            schema.allOf[1].oneOf[0],
          ], subject)
        end
      end
      describe 'allOf failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            allOf:
              - allOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'still applies all' do
          assert_schemas([
            schema,
            schema.allOf[0],
            schema.allOf[0].allOf[0],
            schema.allOf[0].allOf[1],
            schema.allOf[1],
            schema.allOf[1].oneOf[0],
          ], subject)
        end
      end
      describe 'anyOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - {}
              - {type: integer}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies the ones that validate' do
          assert_schemas([
            schema,
            schema.anyOf[0],
            schema.anyOf[2],
          ], subject)
          refute_is_a(schema.anyOf[1].jsi_schema_module, subject)
        end
      end
      describe 'applicators through anyOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - anyOf:
                  - {}
              - oneOf:
                  - {}
              - allOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies those that validate' do
          assert_schemas([
            schema,
            schema.anyOf[0],
            schema.anyOf[0].anyOf[0],
            schema.anyOf[1],
            schema.anyOf[1].oneOf[0],
          ], subject)
          refute_is_a(schema.anyOf[2].jsi_schema_module, subject)
          refute_is_a(schema.anyOf[2].allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'anyOf, all failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            anyOf:
              - anyOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                  - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies all' do
          assert_schemas([
            schema,
            schema.anyOf[0],
            schema.anyOf[0].anyOf[0],
            schema.anyOf[0].anyOf[1],
            schema.anyOf[1],
            schema.anyOf[1].oneOf[0],
          ], subject)
        end
      end
      describe 'oneOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - {not: {}}
              - {type: integer}
              - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies the one that validates' do
          assert_schemas([
            schema,
            schema.oneOf[2],
          ], subject)
          refute_is_a(schema.oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[1].jsi_schema_module, subject)
        end
      end
      describe 'applicators through oneOf' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - oneOf:
                  - {}
                  - {}
              - anyOf:
                  - {}
              - allOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies one' do
          assert_schemas([
            schema,
            schema.oneOf[1],
            schema.oneOf[1].anyOf[0],
          ], subject)
          refute_is_a(schema.oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[0].oneOf[1].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[2].jsi_schema_module, subject)
          refute_is_a(schema.oneOf[2].allOf[0].jsi_schema_module, subject)
        end
      end
      describe 'oneOf, all failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            oneOf:
              - oneOf:
                  - {type: integer}
                  - {not: {}}
              - allOf:
                  - type: integer
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies all' do
          assert_schemas([
            schema,
            schema.oneOf[0],
            schema.oneOf[0].oneOf[0],
            schema.oneOf[0].oneOf[1],
            schema.oneOf[1],
            schema.oneOf[1].allOf[0],
          ], subject)
        end
      end
    end
  end
  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe "#{name} inplace dependencies application" do
      let(:metaschema) { metaschema }
      describe 'dependencies' do
        let(:schema_content) do
          YAML.load(<<~YAML
            dependencies:
              foo: {}
              bar: {}
            YAML
          )
        end
        let(:instance) { {'foo' => [0], 'baz' => {}} }
        it 'applies the ones present' do
          assert_schemas([
            schema,
            schema.dependencies['foo'],
          ], subject)
          refute_is_a(schema.dependencies['bar'].jsi_schema_module, subject)
        end
      end
      describe 'applicators through dependencies' do
        let(:schema_content) do
          YAML.load(<<~YAML
            dependencies:
              foo:
                allOf:
                  - {}
                  - dependencies:
                      foo: {}
                      bar: {}
              bar:
                oneOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {'foo' => [0], 'baz' => {}} }
        it 'applies the ones present' do
          assert_schemas([
            schema,
            schema.dependencies['foo'],
            schema.dependencies['foo'].allOf[0],
            schema.dependencies['foo'].allOf[1],
            schema.dependencies['foo'].allOf[1].dependencies['foo']
          ], subject)
          refute_is_a(schema.dependencies['foo'].allOf[1].dependencies['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependencies['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependencies['bar'].oneOf[0].jsi_schema_module, subject)
        end
      end
      describe 'dependencies, all failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            dependencies:
              foo:
                allOf:
                  - {not: {}}
                  - dependencies:
                      foo: {not: {}}
                      bar: {}
              bar:
                oneOf:
                  - type: string
            YAML
          )
        end
        let(:instance) { {'foo' => [0], 'baz' => {}} }
        it 'applies the ones present (regardless of validation)' do
          assert_schemas([
            schema,
            schema.dependencies['foo'],
            schema.dependencies['foo'].allOf[0],
            schema.dependencies['foo'].allOf[1],
            schema.dependencies['foo'].allOf[1].dependencies['foo']
          ], subject)
          refute_is_a(schema.dependencies['foo'].allOf[1].dependencies['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependencies['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependencies['bar'].oneOf[0].jsi_schema_module, subject)
        end
      end
    end
  end
  {
    draft07: JSI::JSONSchemaDraft07,
  }.each do |name, metaschema|
    describe "#{name} inplace if/then/else application" do
      let(:metaschema) { metaschema }
      describe 'if/then' do
        let(:schema_content) do
          YAML.load(<<~YAML
            if: {}
            then: {}
            else: {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies then' do
          assert_schemas([
            schema,
            schema['then'],
          ], subject)
          refute_is_a(schema['if'].jsi_schema_module, subject)
          refute_is_a(schema['else'].jsi_schema_module, subject)
        end
      end
      describe 'if/else' do
        let(:schema_content) do
          YAML.load(<<~YAML
            if: {not: {}}
            then: {}
            else: {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies else' do
          assert_schemas([
            schema,
            schema['else'],
          ], subject)
          refute_is_a(schema['if'].jsi_schema_module, subject)
          refute_is_a(schema['then'].jsi_schema_module, subject)
        end
      end
      describe 'applicators through if/then' do
        let(:schema_content) do
          YAML.load(<<~YAML
            if:
              oneOf:
                - true
            then:
              allOf:
                - oneOf:
                    - {}
                - false
            else:
              anyOf:
                - {}
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies then' do
          assert_schemas([
            schema,
            schema['then'],
            schema['then'].allOf[0],
            schema['then'].allOf[0].oneOf[0],
            schema['then'].allOf[1],
          ], subject)
          refute_is_a(schema['if'].jsi_schema_module, subject)
          refute_is_a(schema['if'].oneOf[0].jsi_schema_module, subject)
          refute_is_a(schema['else'].jsi_schema_module, subject)
          refute_is_a(schema['else'].anyOf[0].jsi_schema_module, subject)
        end
      end
      describe 'applicators through if/else' do
        let(:schema_content) do
          YAML.load(<<~YAML
            if: false
            then: true
            else:
              if: false
              else: false
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies else' do
          assert_schemas([
            schema,
            schema['else'],
            schema['else']['else'],
          ], subject)
          refute_is_a(schema['if'].jsi_schema_module, subject)
          refute_is_a(schema['then'].jsi_schema_module, subject)
          refute_is_a(schema['else']['if'].jsi_schema_module, subject)
        end
      end
      describe 'if/then, failing validation' do
        let(:schema_content) do
          YAML.load(<<~YAML
            if: true
            then: false
            else: false
            YAML
          )
        end
        let(:instance) { {} }
        it 'applies then' do
          assert_schemas([
            schema,
            schema['then'],
          ], subject)
          refute_is_a(schema['if'].jsi_schema_module, subject)
          refute_is_a(schema['else'].jsi_schema_module, subject)
        end
      end
    end
  end

  describe("Base class for schemas: ancestry of in-place applicators' JSI Schema Modules") do
    let(:metaschema) { JSI::JSONSchemaDraft07 }
    let(:schema_content) do
      {
        allOf: [{}, {}],
      }
    end
    let(:instance) { {} }

    it("methods of a schema's module override methods of modules of in-place applicators") do
      schema.jsi_each_descendent_node.select(&:jsi_is_schema?).each do |desc_schema|
        desc_schema.jsi_schema_module_exec do
          define_method(:methodtest) { {schema_ptr: desc_schema.jsi_ptr} }
        end
      end
      assert_schemas([schema, schema.allOf[0], schema.allOf[1]], subject)
      assert_equal({schema_ptr: JSI::Ptr[]}, subject.methodtest)
    end
  end
end

$test_report_file_loaded[__FILE__]
