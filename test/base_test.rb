require_relative 'test_helper'

NamedSchemaInstance = JSI.new_schema({
  '$schema' => 'http://json-schema.org/draft-07/schema#',
  '$id' => 'http://jsi/base/named_schema',
}).new_jsi({}).class

# hitting .tap(&:name) causes JSI to assign a constant name from the ID,
# meaning the name NamedSchemaInstanceTwo is not known.
NamedSchemaInstanceTwo = JSI.new_schema({
  '$schema' => 'http://json-schema.org/draft-07/schema#',
  '$id' => 'http://jsi/base/named_schema_two',
}).new_jsi({}).class.tap(&:name)

Phonebook = JSI.new_schema_module(YAML.load(<<~YAML
  $schema: http://json-schema.org/draft-07/schema
  title: Phone Book
  properties:
    contacts:
      title: Contact
      properties:
        phone_numbers:
          items:
            title: Phone Number
            properties:
              number: {}
              location: {}
              country:
                properties:
                  code: {}
  YAML
))
module Phonebook
  Contact = properties['contacts']
  module Contact
    PhoneNumber = properties['phone_numbers'].items
  end
end

describe JSI::Base do
  let(:schema_content) { {} }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }
  describe 'class .inspect' do
    it 'is the same as Class#inspect on the base' do
      assert_equal('JSI::Base', JSI::Base.inspect)
    end
    it 'is (JSI Schema Class) for generated subclass without id' do
      assert_equal("(JSI Schema Class: #)", subject.class.inspect)
    end
    describe 'with schema id' do
      let(:schema_content) { {'$id' => 'https://jsi/foo'} }
      it 'is (JSI Schema Class: ...) for generated subclass with id' do
        assert_equal("(JSI Schema Class: https://jsi/foo)", subject.class.inspect)
      end
    end
    it 'is the constant name plus id for a class assigned to a constant' do
      assert_equal(%q(NamedSchemaInstance (http://jsi/base/named_schema)), NamedSchemaInstance.inspect)
    end
    it 'is not the constant name when the constant name has been generated from the schema_uri' do
      assert_equal("JSI::SchemaClasses::Xhttp___jsi_base_named_schema_two", NamedSchemaInstanceTwo.name)
      assert_equal("(JSI Schema Class: http://jsi/base/named_schema_two)", NamedSchemaInstanceTwo.inspect)
    end
  end
  describe 'class name' do
    let(:schema_content) { {'$id' => 'https://jsi/BaseTest'} }
    it 'generates a class name from module name' do
      assert_equal('JSI::SchemaClasses::XPhonebook', Phonebook.new_jsi({}).class.name)
    end
    it 'generates a class name from module name_from_ancestor' do
      assert_equal('JSI::SchemaClasses::XPhonebook__Contact_properties_phone_numbers', Phonebook::Contact.properties['phone_numbers'].new_jsi([]).class.name)
    end
    it 'generates a class name from schema_uri' do
      assert_equal('JSI::SchemaClasses::Xhttps___jsi_BaseTest', subject.class.name)
    end
    it 'uses an existing name' do
      assert_equal('NamedSchemaInstance', NamedSchemaInstance.name)
    end
  end
  describe 'class for schema .jsi_class_schemas' do
    it '.jsi_class_schemas' do
      assert_equal(Set[schema], schema.new_jsi({}).class.jsi_class_schemas)
    end
  end
  describe 'module for schema .inspect' do
    it '.inspect' do
      assert_equal("(JSI Schema Module: #)", JSI::SchemaClasses.module_for_schema(schema).inspect)
    end
  end
  describe 'module for schema .schema' do
    it '.schema' do
      assert_equal(schema, JSI::SchemaClasses.module_for_schema(schema).schema)
    end
  end
  describe '.class_for_schemas' do
    it 'returns a class from a schema' do
      class_for_schema = JSI::SchemaClasses.class_for_schemas([schema])
      # same class every time
      assert_equal(JSI::SchemaClasses.class_for_schemas([schema]), class_for_schema)
      # schema_again same as `schema` but different instantiation; class_for_schemas returns same class
      schema_again = JSI::JSONSchemaOrgDraft07.new_schema({})
      assert_equal(JSI::SchemaClasses.class_for_schemas([schema_again]), class_for_schema)
      assert_operator(class_for_schema, :<, JSI::Base)
    end
    it 'raises given a nonschema' do
      assert_raises(JSI::Schema::NotASchemaError) { JSI::SchemaClasses.class_for_schemas([schema_content]) }
    end
  end
  describe 'JSI::SchemaClasses.module_for_schema' do
    it 'returns a module from a schema' do
      module_for_schema = JSI::SchemaClasses.module_for_schema(schema)
      # same module every time
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), module_for_schema)
    end
    it 'raises given a nonschema' do
      assert_raises(JSI::Schema::NotASchemaError) { JSI::SchemaClasses.module_for_schema(schema_content) }
    end
  end
  describe 'initialization' do
    describe 'nil' do
      let(:instance) { nil }
      it 'initializes with nil instance' do
        assert_equal(nil, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary instance' do
      let(:instance) { Object.new }
      it 'initializes' do
        assert_equal(instance, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:instance) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal({'foo' => 'bar'}, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'SortOfHash' do
      let(:instance) { SortOfHash.new({'foo' => 'bar'}) }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(SortOfHash.new({'foo' => 'bar'}), subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'array' do
      let(:instance) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(['foo'], subject.jsi_instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'SortOfArray' do
      let(:instance) { SortOfArray.new(['foo']) }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(SortOfArray.new(['foo']), subject.jsi_instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'another JSI::Base invalid' do
      let(:schema_content) { {'type' => 'object'} }
      let(:instance) { schema.new_jsi({'foo' => 'bar'}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_equal(%q(a JSI::Base instance must not be another JSI::Base. received: #{<JSI> "foo" => "bar"}), err.message)
      end
    end
    describe 'Schema invalid' do
      let(:instance) { JSI::JSONSchemaOrgDraft06.new_schema({}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_equal(%q(a JSI::Base instance must not be another JSI::Base. received: #{<JSI (JSI::JSONSchemaOrgDraft06) Schema>}), err.message)
      end
    end
  end

  describe '#jsi_schemas' do
    let(:schema_content) do
      {
        "type" => "object",
        "properties" => {
          "phone" => {
            "type" => "array",
          }
        }
      }
    end
    let(:instance) { {'phone' => [{}]} }
    it 'has jsi_schemas' do
      assert_schemas([schema], subject)
      assert_schemas([schema.properties['phone']], subject.phone)
    end
  end

  describe '#jsi_parent_nodes, #jsi_parent_node' do
    let(:schema_content) { {'properties' => {'foo' => {'properties' => {'bar' => {'properties' => {'baz' => {}}}}}}} }
    let(:instance) { {'foo' => {'bar' => {'baz' => {}}}} }
    describe 'no jsi_parent_nodes' do
      it 'has none' do
        assert_equal([], subject.jsi_parent_nodes)
        assert_equal(nil, subject.jsi_parent_node)
      end
    end
    describe 'one jsi_parent_node' do
      it 'has one' do
        assert_equal([subject], subject.foo.jsi_parent_nodes)
        assert_equal(subject, subject.foo.jsi_parent_node)
      end
    end
    describe 'more jsi_parent_nodes' do
      it 'has more' do
        assert_equal([subject.foo.bar, subject.foo, subject], subject.foo.bar.baz.jsi_parent_nodes)
        assert_equal(subject.foo.bar, subject.foo.bar.baz.jsi_parent_node)
      end
    end
    describe 'jsi_parent_nodes not described by schemas' do
      let(:instance) { {'foo' => {'a' => {'b' => ['c']}}} }
      it 'has more' do
        a = subject.foo['a', as_jsi: true]
        b = a['b', as_jsi: true]
        c = b[0, as_jsi: true] # TODO use jsi_child_node or evaluate
        assert_equal([b, a, subject.foo, subject], c.jsi_parent_nodes)
        assert_equal(b, c.jsi_parent_node)
        assert_equal(a, b.jsi_parent_node)
      end
    end
  end
  describe '#each, Enumerable methods' do
    let(:instance) { 'a string' }
    it "raises NoMethodError calling each or Enumerable methods" do
      assert_raises(NoMethodError) { subject.each { nil } }
      assert_raises(NoMethodError) { subject.map { nil } }
    end
  end
  describe '#jsi_each_descendent_node' do
    let(:schema_content) do
      {
        'properties' => {
          'foo' => {'items' => {'title' => 'foo items'}},
        },
        'additionalProperties' => {'title' => 'addtl'},
      }
    end

    describe 'iterating a complex structure' do
      let(:instance) { {'foo' => ['x', []], 'bar' => [9]} }
      it "yields JSIs with the right schemas" do
        descendent_nodes = subject.jsi_each_descendent_node.to_a
        assert_equal({
          JSI::Ptr[] => Set[schema],
          JSI::Ptr["foo"] => Set[schema.properties['foo']],
          JSI::Ptr["foo", 0] => Set[schema.properties['foo'].items],
          JSI::Ptr["foo", 1] => Set[schema.properties['foo'].items],
          JSI::Ptr["bar"] => Set[schema.additionalProperties],
          JSI::Ptr["bar", 0] => Set[],
        }, descendent_nodes.map { |node| {node.jsi_ptr => node.jsi_schemas} }.inject({}, &:update))
      end
    end
    describe 'iterating a simple structure' do
      let(:instance) { 0 }
      it "yields a JSI with the right schemas" do
        descendent_nodes = subject.jsi_each_descendent_node.to_a
        assert_equal({
          JSI::Ptr[] => Set[schema],
        }, descendent_nodes.map { |node| {node.jsi_ptr => node.jsi_schemas} }.inject({}, &:update))
      end
    end
  end
  describe 'selecting descendent nodes' do
    let(:schema_content) do
      YAML.safe_load(<<~YAML
        patternProperties:
          ...:
            $ref: "#"
        items:
          - $ref: "#"
          - $ref: "#"
        pattern: "..."
        YAML
      )
    end
    describe '#jsi_select_descendents_node_first: selecting in a complex structure those elements described by a schema or subschema' do
      # note that 'described by a schema' does not imply the instance or subinstance validates against
      # its schema(s). string subinstances ('y') are described but fail validation against `pattern`.
      let(:instance) do
        YAML.safe_load(<<~YAML
          n:
            n: []
          yyy:
            - y
            - n:   [y, {yyy: y}, n, {nnn: n}] # the 'y's in the value here are irrelevant as they are below a 'n'
              yyy: [y, {yyy: y}, n, {nnn: n}]
            - n
          YAML
        )
      end
      it "selects the nodes" do
        exp = schema.new_jsi({
          'yyy' => [
            'y',
            {'yyy' => ['y', {'yyy' => 'y'}]},
          ]
        })
        act = subject.jsi_select_descendents_node_first do |node|
          node.jsi_schemas.any?
        end
        assert_equal(exp, act)
      end
    end
    describe 'jsi_select_descendents_leaf_first: selecting in a complex structure by validity' do
      # here we select valid leaf nodes and thereby end up with a result consisting of valid descendent nodes
      let(:instance) do
        YAML.safe_load(<<~YAML
          y: # valid because no schema applies to this or its descendents
            y: [y]
          yyy: # will be valid when its invalid descendents are rejected
            - n # fails pattern
            - y:   [y] # valid; no schemas apply
              yyy: [[yyy, n], {nnn: n}, yyy]
            - yyy
          YAML
        )
      end
      it "selects the nodes" do
        exp = schema.new_jsi({
          'y' => {'y' => ['y']},
          'yyy' => [
            {
              'y' => ['y'],
              'yyy' => [['yyy'], {}, 'yyy']
            },
            'yyy',
          ]
        })
        act = subject.jsi_select_descendents_leaf_first(&:jsi_valid?)
        assert_equal(exp, act)
      end
    end
  end
  describe '#jsi_modified_copy' do
    describe 'with an instance that does not have #jsi_modified_copy' do
      let(:instance) { Object.new }
      it 'yields the instance to modify' do
        new_instance = Object.new
        modified = subject.jsi_modified_copy do |o|
          assert_equal(instance, o)
          new_instance
        end
        assert_equal(new_instance, modified.jsi_instance)
        assert_equal(instance, subject.jsi_instance)
        refute_equal(instance, modified)
      end
    end
    describe 'with an instance of the same type' do
      it 'yields the instance to modify' do
        modified = subject.jsi_modified_copy do |o|
          assert_equal({}, o)
          {'a' => 'b'}
        end
        assert_equal({'a' => 'b'}, modified.jsi_instance)
        assert_equal({}, subject.jsi_instance)
        refute_equal(instance, modified)
      end
    end
    describe 'no modification' do
      it 'yields the instance to modify' do
        modified = subject.jsi_modified_copy { |o| o }
        # this doesn't really need to be tested but ... whatever
        assert_equal(subject.jsi_instance.object_id, modified.jsi_instance.object_id)
        assert_equal(subject, modified)
        refute_equal(subject.object_id, modified.object_id)
      end
    end
    describe 'resulting in a different type' do
      let(:schema_content) { {'type' => 'object'} }
      it 'works' do
        # I'm not really sure the best thing to do here, but this is how it is for now. this is subject to change.
        modified = subject.jsi_modified_copy do |o|
          o.to_s
        end
        assert_equal('{}', modified.jsi_instance)
        assert_equal({}, subject.jsi_instance)
        refute_equal(instance, modified)
        # interesting side effect
        assert(subject.respond_to?(:to_hash))
        assert(!modified.respond_to?(:to_hash))
      end
    end
    describe 'resulting in a different type below the root' do
      let(:schema_content) { {items: {}} }
      let(:instance) { [{}] }
      it 'changes type' do
        modified = subject.jsi_modified_copy do |o|
          o.map(&:to_s)
        end
        assert_equal(schema.new_jsi(['{}']), modified)
      end
      it 'changes from complex to a basic type' do
        mod = subject[0].jsi_modified_copy { |o| o.to_s }
        assert_equal(schema.new_jsi(['{}'])[0, as_jsi: true], mod)
      end
    end
    describe 'resulting in a different schema' do
      let(:schema_content) { {items: {oneOf: [{type: 'object'}, {type: 'array'}]}} }
      let(:instance) { [{}] }
      it 'changes schemas' do
        modified = subject.jsi_modified_copy do |o|
          o.map(&:to_a)
        end
        assert_equal([[]], modified.jsi_instance)
        assert_equal([{}], subject.jsi_instance)
        assert_schemas([schema.items, schema.items.oneOf[1]], modified.first)
        assert_schemas([schema.items, schema.items.oneOf[0]], subject.first)
        assert(!modified.first.respond_to?(:to_hash))
        assert(modified.first.respond_to?(:to_ary))
        assert(subject.first.respond_to?(:to_hash))
        assert(!subject.first.respond_to?(:to_ary))
      end
    end
  end
  describe 'validation' do
    describe 'without errors' do
      it '#jsi_validate' do
        result = subject.jsi_validate
        assert_equal(true, result.valid?)
        assert_equal(Set[], result.validation_errors)
        assert_equal(Set[], result.schema_issues)
      end
      it '#jsi_valid?' do
        assert_equal(true, subject.jsi_valid?)
      end
    end
    describe 'with errors' do
      let(:schema_content) {
        {
          '$id' => 'http://jsi/base/validation/with errors',
          'type' => 'object',
          'properties' => {
            'some_number' => {
              'type' => 'number'
            },
            'a_required_property' => {
              'type' => 'string'
            }
          }
        }
      }
      let(:instance) { "this is a string" }

      it '#jsi_valid?' do
        assert_equal(false, subject.jsi_valid?)
      end
      it '#jsi_validate' do
        result = subject.jsi_validate
        assert_equal(false, result.valid?)
        assert_equal(Set[
          JSI::Validation::Error.new({
            message: "instance type does not match `type` value",
            keyword: "type",
            schema: schema,
            instance_ptr: JSI::Ptr[], instance_document: instance,
          }),
        ], result.validation_errors)
        assert_equal(Set[], result.schema_issues)
      end
    end
    describe 'at a depth' do
      let(:schema_content) do
        {
          '$id' => 'http://jsi/base/validation/at a depth',
          'description' => 'hash schema',
          'type' => 'object',
          'properties' => {
            'foo' => {'type' => 'object'},
            'bar' => {},
            'baz' => {'type' => 'array'},
          },
          'additionalProperties' => {'not' => {}},
        }
      end

      describe 'without errors' do
        let(:instance) { {'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => [true]} }

        it '#jsi_validate' do
          assert_equal(true, subject.foo.jsi_validate.valid?)
          assert_equal(Set[], subject.foo.jsi_validate.validation_errors)
          assert_equal(true, subject.bar.jsi_validate.valid?)
          assert_equal(Set[], subject.bar.jsi_validate.validation_errors)
        end
        it '#jsi_valid?' do
          assert_equal(true, subject.foo.jsi_valid?)
          assert_equal(true, subject.bar.jsi_valid?)
        end
      end
      describe 'with errors' do
        let(:instance) { {'foo' => [true], 'bar' => [9], 'baz' => {'x' => 'y'}, 'more' => {}} }

        it '#jsi_validate' do
          assert_equal(Set[
            JSI::Validation::Error.new({
              message: "instance type does not match `type` value",
              keyword: "type",
              schema: schema["properties"]["foo"],
              instance_ptr: JSI::Ptr["foo"], instance_document: instance,
            }),
          ], subject.foo.jsi_validate.validation_errors)
          assert_equal(Set[], subject.bar.jsi_validate.validation_errors)
          assert_equal(Set[
            JSI::Validation::Error.new({
              message: "instance type does not match `type` value",
              keyword: "type",
              schema: schema["properties"]["baz"],
              instance_ptr: JSI::Ptr["baz"], instance_document: instance,
            }),
          ], subject.baz.jsi_validate.validation_errors)
          assert_equal(Set[
            JSI::Validation::Error.new({
              message: "instance is valid against the schema specified as `not` value",
              keyword: "not",
              schema: schema["additionalProperties"],
              instance_ptr: JSI::Ptr["more"], instance_document: instance,
            }),
          ], subject['more'].jsi_validate.validation_errors)
          assert_equal(Set[
            JSI::Validation::Error.new({
              message: "instance type does not match `type` value",
              keyword: "type",
              schema: schema["properties"]["foo"],
              instance_ptr: JSI::Ptr["foo"], instance_document: instance,
            }),
            JSI::Validation::Error.new({
              message: "instance type does not match `type` value",
              keyword: "type",
              schema: schema["properties"]["baz"],
              instance_ptr: JSI::Ptr["baz"], instance_document: instance,
            }),
            JSI::Validation::Error.new({
              message: "instance object properties are not all valid against corresponding `properties` schema values",
              keyword: "properties",
              schema: schema,
              instance_ptr: JSI::Ptr[], instance_document: instance,
            }),
            JSI::Validation::Error.new({
              message: "instance is valid against the schema specified as `not` value",
              keyword: "not",
              schema: schema["additionalProperties"],
              instance_ptr: JSI::Ptr["more"], instance_document: instance,
            }),
            JSI::Validation::Error.new({
              message: "instance object additional properties are not all valid against `additionalProperties` schema value",
              keyword: "additionalProperties",
              schema: schema,
              instance_ptr: JSI::Ptr[], instance_document: instance,
            }),
          ], subject.jsi_validate.validation_errors)
        end
        it '#jsi_valid?' do
          assert_equal(false, subject.foo.jsi_valid?)
          assert_equal(true, subject.bar.jsi_valid?)
          assert_equal(false, subject.baz.jsi_valid?)
          assert_equal(false, subject['more'].jsi_valid?)
          assert_equal(false, subject.jsi_valid?)
        end
      end
    end
  end
  describe 'property accessors' do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'type' => 'object'},
          'bar' => {'type' => 'array'},
          'baz' => {},
        },
      }
    end
    let(:instance) do
      {'foo' => {'x' => 'y'}, 'bar' => [3.14159], 'baz' => true, 'qux' => []}
    end
    describe 'readers' do
      it 'reads attributes described as properties' do
        assert_equal({'x' => 'y'}, subject.foo.jsi_instance)
        assert_schemas([schema.properties['foo']], subject.foo)
        assert_respond_to(subject.foo, :to_hash)
        refute_respond_to(subject.foo, :to_ary)
        assert_equal([3.14159], subject.bar.jsi_instance)
        assert_schemas([schema.properties['bar']], subject.bar)
        refute_respond_to(subject.bar, :to_hash)
        assert_respond_to(subject.bar, :to_ary)
        assert_equal(true, subject.baz)
        refute_respond_to(subject.baz, :to_hash)
        refute_respond_to(subject.baz, :to_ary)
        refute_respond_to(subject, :qux)
      end
      it 'passes as_jsi option' do
        assert_equal({'x' => 'y'}, subject.foo(as_jsi: false))
        assert_schemas([schema.properties['baz']], subject.baz(as_jsi: true))
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(JSI::Base::CannotSubscriptError) { subject.foo }
          assert_equal(%q(cannot subscript (using token: "foo") from instance: nil), err.message)
        end
      end
      describe 'properties with the same names as instance methods' do
        let(:schema_content) do
          {
            'type' => 'object',
            'properties' => {
              'foo' => {},            # not an instance method
              'initialize' => {},     # Base
              'inspect' => {},        # Base
              'pretty_inspect' => {}, # Kernel
              'as_json' => {},        # Base::OverrideFromExtensions, extended on initialization
              'each' => {},           # Base::HashNode / Base::ArrayNode
              'instance_exec' => {},  # BasicObject
              'jsi_instance' => {},   # Base
              'jsi_schemas' => {},    # module_for_schema singleton definition
            },
          }
        end
        let(:instance) do
          {
            'foo' => 'bar',
            'initialize' => 'hi',
            'inspect' => 'hi',
            'pretty_inspect' => 'hi',
            'as_json' => 'hi',
            'each' => 'hi',
            'instance_exec' => 'hi',
            'jsi_instance' => 'hi',
            'jsi_schemas' => 'hi',
          }
        end
        it 'does not define readers' do
          assert_equal('bar', subject.foo) # this one is defined

          assert_equal(JSI::Base, subject.method(:initialize).owner)
          assert_equal('hi', subject['initialize'])
          assert_equal(%q(#{<JSI> "foo" => "bar", "initialize" => "hi", "inspect" => "hi", "pretty_inspect" => "hi", "as_json" => "hi", "each" => "hi", "instance_exec" => "hi", "jsi_instance" => "hi", "jsi_schemas" => "hi"}), subject.inspect)
          assert_equal('hi', subject['inspect'])
          assert_equal(%Q(\#{<JSI>\n  "foo" => "bar",\n  "initialize" => "hi",\n  "inspect" => "hi",\n  "pretty_inspect" => "hi",\n  "as_json" => "hi",\n  "each" => "hi",\n  "instance_exec" => "hi",\n  "jsi_instance" => "hi",\n  "jsi_schemas" => "hi"\n}\n), subject.pretty_inspect)
          assert_equal(instance, subject.as_json)
          assert_equal(subject, subject.each { })
          assert_equal(2, subject.instance_exec { 2 })
          assert_equal(instance, subject.jsi_instance)
          assert_schemas([schema], subject)
        end
      end
      describe 'properties with names to ignore' do
        class X
          # :nocov:
          def to_s
            'x'
          end
          # :nocov:
        end
        let(:schema_content) do
          {
            'type' => 'object',
            'properties' => {
              X.new => {}, # not a string
              '[]' => {}, # operator, also conflicts with Base
              '-@' => {}, # unary operator
              '~' => {},  # unary operator
              '%' => {},  # binary operator
              '0' => {}, # digit
              1 => {}, # digit, not a string
           },
          }
        end
        let(:instance) do
          {
            X.new => 'x',
            '[]' => '[]',
            '-@' => '-@',
            '~' => '~',
            '%' => '%',
            '0' => '0',
            1 => 1,
          }
        end
        it 'does not define readers' do
          assert_raises(NoMethodError) { subject.x }
          assert_equal(nil, subject['test']) # #[] would SystemStackError since reader calls #[]
          assert_equal(JSI::Base, subject.method(:[]).owner)
          assert_raises(NoMethodError) { -subject }
          assert_raises(NoMethodError) { ~subject }
          assert_raises(NoMethodError) { subject % 0 }
          assert_raises(NoMethodError) { subject.send('0') }
          assert_raises(NoMethodError) { subject.send('1') }
        end
      end

      describe 'property named unicode 😀' do
        let(:schema_content) do
          {
            'type' => 'object',
            'properties' => {
              '😀' => {}
           },
          }
        end
        let(:instance) do
          {
            '😀' => '💜'
          }
        end
        it 'defines reader and writer' do
          assert_equal('💜', subject.😀)
          subject.😀= '💚'
          assert_equal('💚', subject.😀)
        end
      end
    end
    describe 'writers' do
      it 'writes attributes described as properties' do
        orig_foo = subject.foo

        subject.foo = {'y' => 'z'}

        assert_equal({'y' => 'z'}, subject.foo.jsi_instance)
        assert_schemas([schema.properties['foo']], orig_foo)
        assert_schemas([schema.properties['foo']], subject.foo)
      end
      it 'modifies the instance, visible to other references to the same instance' do
        orig_instance = subject.jsi_instance

        subject.foo = {'y' => 'z'}

        assert_equal(orig_instance, subject.jsi_instance)
        assert_equal({'y' => 'z'}, orig_instance['foo'])
        assert_equal({'y' => 'z'}, subject.jsi_instance['foo'])
        assert_equal(orig_instance.class, subject.jsi_instance.class)
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(JSI::Base::CannotSubscriptError) { subject.foo = 0 }
          assert_equal('cannot assign subscript (using token: "foo") to instance: nil', err.message)
        end
      end
    end
  end
  describe '#inspect' do
    # if the instance is hash-like, #inspect gets overridden
    let(:instance) { Object.new }
    it 'inspects' do
      assert_match(%r(\A\#<JSI\ \#<Object:[^<>]*>>\z), subject.inspect)
    end
  end
  describe '#pretty_print' do
    # if the instance is hash-like, #pretty_print gets overridden
    let(:instance) { Object.new }
    it 'pretty_prints' do
      assert_match(%r(\A\#<JSI\ \#<Object:[^<>]*>>\z), subject.pretty_inspect.chomp)
    end
  end
  describe 'name_from_ancestor #inspect #pretty_print' do
    let(:phonebook) do
      Phonebook.new_jsi(YAML.safe_load(<<~YAML
        contacts:
          phone_numbers:
            - number: '2'
              location: 'office'
              country:
                code: 'us'
        YAML
      ))
    end
    it "shows the schema modules' name_from_ancestor" do
      assert_equal(%q(#{<JSI (Phonebook)> "contacts" => #{<JSI (Phonebook::Contact)> "phone_numbers" => #[<JSI (Phonebook::Contact.properties["phone_numbers"])> #{<JSI (Phonebook::Contact::PhoneNumber)> "number" => "2", "location" => "office", "country" => #{<JSI (Phonebook::Contact::PhoneNumber.properties["country"])> "code" => "us"}}]}}), phonebook.inspect)
      pp = <<~PP
        \#{<JSI (Phonebook)>
          "contacts" => \#{<JSI (Phonebook::Contact)>
            "phone_numbers" => \#[<JSI (Phonebook::Contact.properties["phone_numbers"])>
              \#{<JSI (Phonebook::Contact::PhoneNumber)>
                "number" => "2",
                "location" => "office",
                "country" => \#{<JSI (Phonebook::Contact::PhoneNumber.properties["country"])>
                  "code" => "us"
                }
              }
            ]
          }
        }
        PP
      assert_equal(pp, phonebook.pretty_inspect)
    end
  end
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, JSI::JSONSchemaOrgDraft07.new_schema({'type' => 'object'}).new_jsi({'a' => 'b'}).as_json)
      assert_equal(['a', 'b'], JSI::JSONSchemaOrgDraft07.new_schema({'type' => 'array'}).new_jsi(['a', 'b']).as_json)
      assert_equal(['a'], JSI::JSONSchemaOrgDraft07.new_schema({}).new_jsi(['a']).as_json(some_option: true))
    end

    describe 'overriding as_json' do
      it 'overrides' do
        # note that since JSIs are extended with Base::ArrayNode/Base::HashNode in #initialize, methods of
        # those modules are not overridden by schema modules (which are included on the instance's class).
        # Enumerable is included on Base (rather than conditionally extending hash/array nodes) so
        # that Enumerable methods can be overridden (in particular as_json - although not defined on
        # Enumerable normally, ActiveSupport defines it)
        schema = JSI::JSONSchemaOrgDraft06.new_schema({'$id' => 'http://jsi/base/def_as_json'})
        schema.jsi_schema_module_exec { define_method(:as_json) { :foo } }
        assert_equal(:foo, schema.new_jsi({}).as_json)
        assert_equal(:foo, schema.new_jsi([]).as_json)
        assert_equal(:foo, schema.new_jsi(0).as_json)
      end
    end
  end
  describe 'equality' do
    describe 'with different jsi_schema_base_uri' do
      let(:schema) { JSI::JSONSchemaOrgDraft06 }
      let(:instance) { {'$id' => '4c01'} }
      it 'is not equal' do
        exp = schema.new_jsi(instance, uri: 'http://jsi/test/802d/')
        act = schema.new_jsi(instance, uri: 'http://jsi/test/802e/')
        refute_equal(exp, act)
        assert_equal('http://jsi/test/802d/4c01', exp.schema_absolute_uri.to_s)
        assert_equal('http://jsi/test/802e/4c01', act.schema_absolute_uri.to_s)
      end
    end
    describe 'the jsi_schema_base_uri is different, but the schema_absolute_uri is unaffected' do
      let(:schema) { JSI::JSONSchemaOrgDraft06 }
      let(:instance) { {'$id' => 'http://jsi/test/a86e'} }
      it 'is not equal' do
        exp = schema.new_jsi(instance, uri: 'http://jsi/test/802d/')
        act = schema.new_jsi(instance, uri: 'http://jsi/test/802e/')
        assert_equal(exp, act)
        assert_equal('http://jsi/test/a86e', exp.schema_absolute_uri.to_s)
        assert_equal('http://jsi/test/a86e', act.schema_absolute_uri.to_s)
      end
    end
  end
end
