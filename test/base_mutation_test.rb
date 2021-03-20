require_relative 'test_helper'

describe JSI::Base do
  let(:schema) { JSI.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  describe 'instance mutation' do
    let(:schema_content) do
      YAML.load(<<~YAML
        $schema: "http://json-schema.org/draft-07/schema#"
        definitions:
          a:
            properties:
              type:
                const: a
          b:
            properties:
              type:
                const: b
        properties:
          ab:
            type: object
            oneOf:
              - $ref: "#/definitions/a"
              - $ref: "#/definitions/b"
        YAML
      )
    end

    let(:instance) do
      YAML.load(<<~YAML
        ab:
          type: a
        YAML
      )
    end

    it 'changes applied child schemas' do
      a_module = schema.definitions['a'].jsi_schema_module
      b_module = schema.definitions['b'].jsi_schema_module

      assert(subject.jsi_valid?)
      assert_is_a(a_module, subject.ab)
      refute_is_a(b_module, subject.ab)

      subject.ab = {'type' => 'b'}
      assert(subject.jsi_valid?)
      refute_is_a(a_module, subject.ab)
      assert_is_a(b_module, subject.ab)

      subject.ab.type = 'a'
      assert(subject.jsi_valid?)
      assert_is_a(a_module, subject.ab)
      refute_is_a(b_module, subject.ab)

      subject.ab = {'type' => 'c'}
      refute(subject.jsi_valid?)
      refute_is_a(a_module, subject.ab)
      refute_is_a(b_module, subject.ab)
    end
  end
end
