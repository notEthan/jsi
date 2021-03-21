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

  describe 'instance mutation affecting adjacent items' do
    let(:schema_content) do
      YAML.load(<<~YAML
        $schema: "http://json-schema.org/draft-07/schema#"
        definitions:
          a:
            {}
          b:
            {}
          as:
            items:
              - const: a
            additionalItems:
              $ref: "#/definitions/a"
          bs:
            items:
              - const: b
            additionalItems:
              $ref: "#/definitions/b"
        properties:
          abs:
            type: array
            oneOf:
              - $ref: "#/definitions/as"
              - $ref: "#/definitions/bs"
        YAML
      )
    end

    let(:instance) do
      YAML.load(<<~YAML
        abs:
          - a
          - {}
        YAML
      )
    end

    it 'changes applied child schemas' do
      a_module = schema.definitions['a'].jsi_schema_module
      b_module = schema.definitions['b'].jsi_schema_module
      as_module = schema.definitions['as'].jsi_schema_module
      bs_module = schema.definitions['bs'].jsi_schema_module

      orig_abs = subject.abs

      assert(subject.jsi_valid?)
      assert_is_a(as_module, subject.abs)
      refute_is_a(bs_module, subject.abs)
      assert_is_a(a_module, subject.abs[1])
      refute_is_a(b_module, subject.abs[1])

      # changing the first element to "b" changes the array to an instance of schema`bs`
      # and each element beyond the first (additionalItems) to `b`s
      subject.abs[0] = 'b'
      assert(subject.jsi_valid?)
      refute_is_a(as_module, subject.abs)
      assert_is_a(bs_module, subject.abs)
      refute_is_a(a_module, subject.abs[1])
      assert_is_a(b_module, subject.abs[1])

      # the orig_abs does not change (it's already instantiated as a `as`).
      # its additionalItems remain `a`s.
      refute(orig_abs.jsi_valid?)
      assert_is_a(as_module, orig_abs)
      refute_is_a(bs_module, orig_abs)
      assert_is_a(a_module, orig_abs[1])
      refute_is_a(b_module, orig_abs[1])
      # but the underlying data are changed.
      assert_equal('b', orig_abs[0])
    end
  end
end
