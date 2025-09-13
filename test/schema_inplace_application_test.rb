require_relative 'test_helper'

describe("JSI Schema in-place application") do
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
        yaml(:schema_content, <<~YAML
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
    describe("#{name} in-place $ref application") do
      let(:metaschema) { metaschema }
      describe '$ref' do
        yaml(:schema_content, <<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            YAML
        )
        let(:instance) { {} }
        it 'applies $ref, excludes the schema containing $ref' do
          assert_schemas([
            schema.definitions['A'],
          ], subject)
          refute_is_a(schema.jsi_schema_module, subject)
        end
      end
      describe '$ref nested' do
        yaml(:schema_content, <<~YAML
            definitions:
              A:
                $ref: "#/definitions/B"
              B:
                {}
            $ref: "#/definitions/A"
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            allOf:
              - {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            definitions:
              A:
                allOf:
                  - {}
            $ref: "#/definitions/A"
            YAML
        )
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
    draft202012: JSI::JSONSchemaDraft202012,
  }.each do |name, metaschema|
    describe("#{name} in-place $ref application") do
      let(:metaschema) { metaschema }

      describe("$ref") do
        yaml(:schema_content, <<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            YAML
        )
        let(:instance) { {} }

        it("applies $ref and the schema containing $ref") do
          assert_schemas([
            schema,
            schema.definitions['A'],
          ], subject)
        end
      end

      describe("$ref nested") do
        yaml(:schema_content, <<~YAML
            definitions:
              A:
                $ref: "#/definitions/B"
              B:
                {}
            $ref: "#/definitions/A"
            YAML
        )
        let(:instance) { {} }

        it("applies") do
          assert_schemas([
            schema,
            schema.definitions['A'],
            schema.definitions['B'],
          ], subject)
        end
      end

      describe("$ref sibling applicators") do
        yaml(:schema_content, <<~YAML
            definitions:
              A: {}
            $ref: "#/definitions/A"
            allOf:
              - {}
            YAML
        )
        let(:instance) { {} }

        it("applies") do
          assert_schemas([
            schema,
            schema.definitions['A'],
            schema.allOf[0],
          ], subject)
        end
      end

      describe("applicators through $ref target") do
        yaml(:schema_content, <<~YAML
            definitions:
              A:
                allOf:
                  - {}
            $ref: "#/definitions/A"
            YAML
        )
        let(:instance) { {} }

        it("applies") do
          assert_schemas([
            schema,
            schema.definitions['A'],
            schema.definitions['A'].allOf[0],
          ], subject)
        end
      end
    end
  end

  # note: $dynamicRef not tested here; I am considering the JSON Schema Test Suite sufficient

  {
    draft04: JSI::JSONSchemaDraft04,
    draft06: JSI::JSONSchemaDraft06,
    draft07: JSI::JSONSchemaDraft07,
    draft202012: JSI::JSONSchemaDraft202012,
  }.each do |name, metaschema|
    describe("#{name} in-place allOf, anyOf, oneOf application") do
      let(:metaschema) { metaschema }
      describe 'allOf' do
        yaml(:schema_content, <<~YAML
            allOf:
              - {}
              - {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            allOf:
              - allOf:
                  - {}
              - oneOf:
                  - {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            allOf:
              - allOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                - type: integer
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            anyOf:
              - {}
              - {type: integer}
              - {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            anyOf:
              - anyOf:
                  - {}
              - oneOf:
                  - {}
              - allOf:
                  - type: string
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            anyOf:
              - anyOf:
                  - {type: integer}
                  - {not: {}}
              - oneOf:
                  - type: integer
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            oneOf:
              - {not: {}}
              - {type: integer}
              - {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
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
        yaml(:schema_content, <<~YAML
            oneOf:
              - oneOf:
                  - {type: integer}
                  - {not: {}}
              - allOf:
                  - type: integer
            YAML
        )
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
    describe("#{name} in-place dependencies application") do
      let(:metaschema) { metaschema }
      describe 'dependencies' do
        yaml(:schema_content, <<~YAML
            dependencies:
              foo: {}
              bar: {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
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
        yaml(:schema_content, <<~YAML
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
    draft202012: JSI::JSONSchemaDraft202012,
  }.each do |name, metaschema|
    describe("#{name} in-place dependentSchemas application") do
      let(:metaschema) { metaschema }

      describe("dependentSchemas") do
        yaml(:schema_content, <<~YAML
            dependentSchemas:
              foo: {}
              bar: {}
            YAML
        )
        let(:instance) { {'foo' => [0], 'baz' => {}} }

        it("applies the ones present") do
          assert_schemas([
            schema,
            schema.dependentSchemas['foo'],
          ], subject)
          refute_is_a(schema.dependentSchemas['bar'].jsi_schema_module, subject)
        end
      end

      describe("applicators through dependentSchemas") do
        yaml(:schema_content, <<~YAML
            dependentSchemas:
              foo:
                allOf:
                  - {}
                  - dependentSchemas:
                      foo: {}
                      bar: {}
              bar:
                oneOf:
                  - type: string
            YAML
        )
        let(:instance) { {'foo' => [0], 'baz' => {}} }

        it("applies the ones present") do
          assert_schemas([
            schema,
            schema.dependentSchemas['foo'],
            schema.dependentSchemas['foo'].allOf[0],
            schema.dependentSchemas['foo'].allOf[1],
            schema.dependentSchemas['foo'].allOf[1].dependentSchemas['foo']
          ], subject)
          refute_is_a(schema.dependentSchemas['foo'].allOf[1].dependentSchemas['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependentSchemas['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependentSchemas['bar'].oneOf[0].jsi_schema_module, subject)
        end
      end

      describe("dependentSchemas, all failing validation") do
        yaml(:schema_content, <<~YAML
            dependentSchemas:
              foo:
                allOf:
                  - {not: {}}
                  - dependentSchemas:
                      foo: {not: {}}
                      bar: {}
              bar:
                oneOf:
                  - type: string
            YAML
        )
        let(:instance) { {'foo' => [0], 'baz' => {}} }

        it("applies the ones present (regardless of validation)") do
          assert_schemas([
            schema,
            schema.dependentSchemas['foo'],
            schema.dependentSchemas['foo'].allOf[0],
            schema.dependentSchemas['foo'].allOf[1],
            schema.dependentSchemas['foo'].allOf[1].dependentSchemas['foo']
          ], subject)
          refute_is_a(schema.dependentSchemas['foo'].allOf[1].dependentSchemas['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependentSchemas['bar'].jsi_schema_module, subject)
          refute_is_a(schema.dependentSchemas['bar'].oneOf[0].jsi_schema_module, subject)
        end
      end
    end
  end

  {
    draft07: JSI::JSONSchemaDraft07,
    draft202012: JSI::JSONSchemaDraft202012,
  }.each do |name, metaschema|
    describe("#{name} in-place if/then/else application") do
      let(:metaschema) { metaschema }
      describe 'if/then' do
        yaml(:schema_content, <<~YAML
            if: {}
            then: {}
            else: {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            if: {not: {}}
            then: {}
            else: {}
            YAML
        )
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
        yaml(:schema_content, <<~YAML
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
        yaml(:schema_content, <<~YAML
            if: false
            then: true
            else:
              if: false
              else: false
            YAML
        )
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
        yaml(:schema_content, <<~YAML
            if: true
            then: false
            else: false
            YAML
        )
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
