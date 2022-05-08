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
      assert(subject.jsi_valid?)
      assert_schema(schema.definitions['a'], subject.ab)
      refute_schema(schema.definitions['b'], subject.ab)

      subject.ab = {'type' => 'b'}
      assert(subject.jsi_valid?)
      refute_schema(schema.definitions['a'], subject.ab)
      assert_schema(schema.definitions['b'], subject.ab)

      subject.ab.type = 'a'
      assert(subject.jsi_valid?)
      assert_schema(schema.definitions['a'], subject.ab)
      refute_schema(schema.definitions['b'], subject.ab)

      subject.ab = {'type' => 'c'}
      refute(subject.jsi_valid?)
      assert_schema(schema.definitions['a'], subject.ab)
      assert_schema(schema.definitions['b'], subject.ab)
    end

    it 'keeps the same child JSI when applied child schemas are the same' do
      ab = subject.ab
      subject.ab['x'] = 'y'
      assert_equal(ab.__id__, subject.ab.__id__)
      subject.ab = {'type' => 'a', 'x' => 'z'}
      assert_equal(ab.__id__, subject.ab.__id__)

      subject.ab.type = 'b'
      refute_equal(ab.__id__, subject.ab.__id__)
      ab = subject.ab
      subject.ab['x'] = 'y'
      assert_equal(ab.__id__, subject.ab.__id__)
      subject.ab = {'type' => 'b', 'x' => 'z'}
      assert_equal(ab.__id__, subject.ab.__id__)

      subject.ab = {'type' => 'c'}
      refute_equal(ab.__id__, subject.ab.__id__)
      ab = subject.ab
      subject.ab['x'] = 'y'
      assert_equal(ab.__id__, subject.ab.__id__)
      subject.ab = {'type' => 'c', 'x' => 'z'}
      assert_equal(ab.__id__, subject.ab.__id__)
    end

    it 'recomputes child JSI when applied child schemas are the same but included modules change' do
      subject.ab = {'type' => 'c'}
      ab = subject.ab
      subject.ab = ['ary']
      refute_equal(ab.__id__, subject.ab.__id__)
      ab = subject.ab
      subject.ab = []
      assert_equal(ab.__id__, subject.ab.__id__)
      ab = subject.ab
      subject.ab = 0
      refute_equal(ab.__id__, subject.ab(as_jsi: true).__id__)
      ab = subject.ab(as_jsi: true)
      subject.ab = false
      assert_equal(ab.__id__, subject.ab(as_jsi: true).__id__)
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
      orig_abs = subject.abs

      assert(subject.jsi_valid?)
      assert_schema(schema.definitions['as'], subject.abs)
      refute_schema(schema.definitions['bs'], subject.abs)
      assert_schema(schema.definitions['a'], subject.abs[1])
      refute_schema(schema.definitions['b'], subject.abs[1])

      # changing the first element to "b" changes the array to an instance of schema`bs`
      # and each element beyond the first (additionalItems) to `b`s
      subject.abs[0] = 'b'
      assert(subject.jsi_valid?)
      refute_schema(schema.definitions['as'], subject.abs)
      assert_schema(schema.definitions['bs'], subject.abs)
      refute_schema(schema.definitions['a'], subject.abs[1])
      assert_schema(schema.definitions['b'], subject.abs[1])

      # the orig_abs does not change (it's already instantiated as a `as`).
      # its additionalItems remain `a`s.
      refute(orig_abs.jsi_valid?)
      assert_schema(schema.definitions['as'], orig_abs)
      refute_schema(schema.definitions['bs'], orig_abs)
      assert_schema(schema.definitions['a'], orig_abs[1])
      refute_schema(schema.definitions['b'], orig_abs[1])
      # but the underlying data are changed.
      assert_equal('b', orig_abs[0])
    end
  end
end
