require_relative 'test_helper'

NamedSchemaInstance = JSI.class_for_schema({id: 'https://schemas.jsi.unth.net/test/base/named_schema'})

describe JSI::Base do
  let(:document) { {} }
  let(:path) { [] }
  let(:instance) { JSI::JSON::Node.new_by_type(document, path) }
  let(:schema_content) { {} }
  let(:schema) { JSI::Schema.new(schema_content) }
  let(:subject) { JSI.class_for_schema(schema).new(instance) }
  describe 'class .inspect + .to_s' do
    it 'is the same as Class#inspect on the base' do
      assert_equal('JSI::Base', JSI::Base.inspect)
      assert_equal('JSI::Base', JSI::Base.to_s)
    end
    it 'is SchemaClasses[] for generated subclass without id' do
      assert_match(%r(\AJSI::SchemaClasses\["[a-f0-9\-]+#"\]\z), subject.class.inspect)
      assert_match(%r(\AJSI::SchemaClasses\["[a-f0-9\-]+#"\]\z), subject.class.to_s)
    end
    describe 'with schema id' do
      let(:schema_content) { {'id' => 'https://jsi/foo'} }
      it 'is SchemaClasses[] for generated subclass with id' do
        assert_equal(%q(JSI::SchemaClasses["https://jsi/foo#"]), subject.class.inspect)
        assert_equal(%q(JSI::SchemaClasses["https://jsi/foo#"]), subject.class.to_s)
      end
    end
    it 'is the constant name (plus id for .inspect) for a class assigned to a constant' do
      assert_equal(%q(NamedSchemaInstance (https://schemas.jsi.unth.net/test/base/named_schema#)), NamedSchemaInstance.inspect)
      assert_equal(%q(NamedSchemaInstance), NamedSchemaInstance.to_s)
    end
  end
  describe 'class name' do
    let(:schema_content) { {'id' => 'https://jsi/BaseTest'} }
    it 'generates a class name from schema_id' do
      assert_equal('JSI::SchemaClasses::Https___jsi_BaseTest_', subject.class.name)
    end
    it 'uses an existing name' do
      assert_equal('NamedSchemaInstance', NamedSchemaInstance.name)
    end
  end
  describe 'class for schema .schema' do
    it '.schema' do
      assert_equal(schema, JSI.class_for_schema(schema).schema)
    end
  end
  describe 'class for schema .schema_id' do
    it '.schema_id' do
      assert_equal(schema.schema_id, JSI.class_for_schema(schema).schema_id)
    end
  end
  describe 'module for schema .inspect' do
    it '.inspect' do
      assert_match(%r(\A#<Module for Schema: .+#>\z), JSI::SchemaClasses.module_for_schema(schema).inspect)
    end
  end
  describe 'module for schema .schema' do
    it '.schema' do
      assert_equal(schema, JSI::SchemaClasses.module_for_schema(schema).schema)
    end
  end
  describe 'SchemaClasses[]' do
    it 'stores the class for the schema' do
      assert_equal(JSI.class_for_schema(schema), JSI::SchemaClasses[schema.schema_id])
    end
  end
  describe '.class_for_schema' do
    it 'returns a class from a schema' do
      class_for_schema = JSI.class_for_schema(schema)
      # same class every time
      assert_equal(JSI.class_for_schema(schema), class_for_schema)
      assert_operator(class_for_schema, :<, JSI::Base)
    end
    it 'returns a class from a hash' do
      assert_equal(JSI.class_for_schema(schema), JSI.class_for_schema(schema.schema_node.content))
    end
    it 'returns a class from a schema node' do
      assert_equal(JSI.class_for_schema(schema), JSI.class_for_schema(schema.schema_node))
    end
    it 'returns a class from a Base' do
      assert_equal(JSI.class_for_schema(schema), JSI.class_for_schema(JSI.class_for_schema({}).new(schema.schema_node)))
    end
  end
  describe 'JSI::SchemaClasses.module_for_schema' do
    it 'returns a module from a schema' do
      module_for_schema = JSI::SchemaClasses.module_for_schema(schema)
      # same module every time
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), module_for_schema)
    end
    it 'returns a module from a hash' do
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), JSI::SchemaClasses.module_for_schema(schema.schema_node.content))
    end
    it 'returns a module from a schema node' do
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), JSI::SchemaClasses.module_for_schema(schema.schema_node))
    end
    it 'returns a module from a Base' do
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), JSI::SchemaClasses.module_for_schema(JSI.class_for_schema({}).new(schema.schema_node)))
    end
  end
  describe 'initialization' do
    describe 'on Base' do
      it 'errors' do
        err = assert_raises(TypeError) { JSI::Base.new({}) }
        assert_equal('cannot instantiate JSI::Base which has no method #schema. please use JSI.class_for_schema', err.message)
      end
    end
    describe 'nil' do
      let(:instance) { nil }
      it 'initializes with nil instance' do
        assert_equal(nil, subject.instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary instance' do
      let(:instance) { Object.new }
      it 'initializes' do
        assert_equal(instance, subject.instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:instance) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal({'foo' => 'bar'}, subject.instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'JSI::JSON::Hashnode' do
      let(:document) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(JSI::JSON::HashNode.new({'foo' => 'bar'}, []), subject.instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'array' do
      let(:instance) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(['foo'], subject.instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'JSI::JSON::Arraynode' do
      let(:document) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(JSI::JSON::ArrayNode.new(['foo'], []), subject.instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'another JSI::Base invalid' do
      let(:schema_content) { {'type' => 'object'} }
      let(:instance) { JSI.class_for_schema(schema).new({'foo' => 'bar'}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_match(%r(\Aassigning another JSI::Base instance to JSI::SchemaClasses\[\".*#\"\] instance is incorrect. received: #\{<JSI::SchemaClasses\[.*\] Hash>\s*"foo" => "bar"\s*\}\z)m, err.message)
      end
    end
    describe 'Schema invalid' do
      let(:instance) { JSI::Schema.new({}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_match(%r(\Aassigning a schema to JSI::SchemaClasses\[\".*#\"\] instance is incorrect. received: #<JSI::Schema schema_id=.*>\z)m, err.message)
      end
    end
  end
  describe '#parents, #parent' do
    let(:schema_content) { {'properties' => {'foo' => {'properties' => {'bar' => {'properties' => {'baz' => {}}}}}}} }
    let(:document) { {'foo' => {'bar' => {'baz' => {}}}} }
    describe 'no parents' do
      it 'has none' do
        assert_equal([], subject.parents)
        assert_equal(nil, subject.parent)
      end
    end
    describe 'one parent' do
      it 'has one' do
        assert_equal([subject], subject.foo.parents)
        assert_equal(subject, subject.foo.parent)
      end
    end
    describe 'more parents' do
      it 'has more' do
        assert_equal([subject.foo.bar, subject.foo, subject], subject.foo.bar.baz.parents)
        assert_equal(subject.foo.bar, subject.foo.bar.baz.parent)
      end
    end
  end
  describe '#each, Enumerable methods' do
    let(:document) { 'a string' }
    it "raises NoMethodError calling each or Enumerable methods" do
      assert_raises(NoMethodError) { subject.each { nil } }
      assert_raises(NoMethodError) { subject.map { nil } }
    end
  end
  describe '#modified_copy' do
    describe 'with an instance that does have #modified_copy' do
      it 'yields the instance to modify' do
        modified = subject.modified_copy do |o|
          assert_equal({}, o)
          {'a' => 'b'}
        end
        assert_equal({'a' => 'b'}, modified.instance.content)
        assert_equal({}, subject.instance.content)
        refute_equal(instance, modified)
      end
    end
    describe 'no modification' do
      it 'yields the instance to modify' do
        modified = subject.modified_copy { |o| o }
        # this doesn't really need to be tested but ... whatever
        assert_equal(subject.instance.content.object_id, modified.instance.content.object_id)
        assert_equal(subject, modified)
        refute_equal(subject.object_id, modified.object_id)
      end
    end
    describe 'resulting in a different type' do
      let(:schema_content) { {'type' => 'object'} }
      it 'works' do
        # I'm not really sure the best thing to do here, but this is how it is for now. this is subject to change.
        modified = subject.modified_copy do |o|
          o.to_s
        end
        assert_equal('{}', modified.instance.content)
        assert_equal({}, subject.instance.content)
        refute_equal(instance, modified)
        # interesting side effect
        assert(subject.respond_to?(:to_hash))
        assert(!modified.respond_to?(:to_hash))
        assert_equal(JSI::JSON::HashNode, subject.instance.class)
        assert_equal(JSI::JSON::Node, modified.instance.class)
      end
    end
  end
  it('#fragment') { assert_equal('#', subject.fragment) }
  describe 'validation' do
    describe 'without errors' do
      it '#fully_validate' do
        assert_equal([], subject.fully_validate)
      end
      it '#validate' do
        assert_equal(true, subject.validate)
      end
      it '#validate!' do
        assert_equal(true, subject.validate!)
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
    let(:document) do
      {'foo' => {'x' => 'y'}, 'bar' => [3.14159], 'baz' => true, 'qux' => []}
    end
    describe 'readers' do
      it 'reads attributes described as properties' do
        assert_equal({'x' => 'y'}, subject.foo.as_json)
        assert_instance_of(JSI.class_for_schema(schema.schema_node['properties']['foo']), subject.foo)
        assert_respond_to(subject.foo, :to_hash)
        refute_respond_to(subject.foo, :to_ary)
        assert_equal([3.14159], subject.bar.as_json)
        assert_instance_of(JSI.class_for_schema(schema.schema_node['properties']['bar']), subject.bar)
        refute_respond_to(subject.bar, :to_hash)
        assert_respond_to(subject.bar, :to_ary)
        assert_equal(true, subject.baz)
        refute_respond_to(subject.baz, :to_hash)
        refute_respond_to(subject.baz, :to_ary)
        refute_respond_to(subject, :qux)
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo }
          assert_match(%r(\Ainstance does not respond to \[\]; cannot call reader `foo' for: #<JSI::SchemaClasses\["[^"]+#"\].*nil.*>\z)m, err.message)
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
              'each' => {},           # BaseHash / BaseArray
              'instance_exec' => {},  # BasicObject
              'instance' => {},       # Base
              'schema' => {},         # module_for_schema singleton definition
            },
          }
        end
        let(:document) do
          {
            'foo' => 'bar',
            'initialize' => 'hi',
            'inspect' => 'hi',
            'pretty_inspect' => 'hi',
            'as_json' => 'hi',
            'each' => 'hi',
            'instance_exec' => 'hi',
            'instance' => 'hi',
            'schema' => 'hi',
          }
        end
        it 'does not define readers' do
          assert_equal('bar', subject.foo)
          assert_equal(JSI::SchemaClasses.module_for_schema(subject.schema), subject.method(:foo).owner)

          assert_equal(JSI::Base, subject.method(:initialize).owner)
          assert_equal('hi', subject['initialize'])
          assert_match(%r(\A#\{<JSI::SchemaClasses\[".*#"\].*}\z)m, subject.inspect)
          assert_equal('hi', subject['inspect'])
          assert_match(%r(\A#\{<JSI::SchemaClasses\[".*#"\].*}\Z)m, subject.pretty_inspect)
          assert_equal(document, subject.as_json)
          assert_equal(subject, subject.each { })
          assert_equal(2, subject.instance_exec { 2 })
          assert_equal(instance, subject.instance)
          assert_equal(schema, subject.schema)
        end
      end
    end
    describe 'writers' do
      it 'writes attributes described as properties' do
        orig_foo = subject.foo

        subject.foo = {'y' => 'z'}

        assert_equal({'y' => 'z'}, subject.foo.as_json)
        assert_instance_of(JSI.class_for_schema(schema.schema_node['properties']['foo']), orig_foo)
        assert_instance_of(JSI.class_for_schema(schema.schema_node['properties']['foo']), subject.foo)
      end
      it 'modifies the instance, visible to other references to the same instance' do
        orig_instance = subject.instance

        subject.foo = {'y' => 'z'}

        assert_equal(orig_instance, subject.instance)
        assert_equal({'y' => 'z'}, orig_instance['foo'].as_json)
        assert_equal({'y' => 'z'}, subject.instance['foo'].as_json)
        assert_equal(orig_instance.class, subject.instance.class)
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo = 0 }
          assert_match(%r(\Ainstance does not respond to \[\]=; cannot call writer `foo=' for: #<JSI::SchemaClasses\["[^"]+#"\].*nil.*>\z)m, err.message)
        end
      end
    end
  end
  describe '#inspect' do
    # if the instance is hash-like, #inspect gets overridden
    let(:document) { Object.new }
    it 'inspects' do
      assert_match(%r(\A#<JSI::SchemaClasses\["[^"]+#"\] #<JSI::JSON::Node fragment="#" #<Object:[^<>]*>>>\z), subject.inspect)
    end
  end
  describe '#pretty_print' do
    # if the instance is hash-like, #pretty_print gets overridden
    let(:document) { Object.new }
    it 'pretty_prints' do
      assert_match(%r(\A#<JSI::SchemaClasses\["[^"]+#"\]\n  #<JSI::JSON::Node fragment="#" #<Object:[^<>]*>>\n>\z), subject.pretty_inspect.chomp)
    end
  end
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, JSI.class_for_schema({}).new(JSI::JSON::Node.new_doc({'a' => 'b'})).as_json)
      assert_equal({'a' => 'b'}, JSI.class_for_schema({'type' => 'object'}).new(JSI::JSON::Node.new_doc({'a' => 'b'})).as_json)
      assert_equal(['a', 'b'], JSI.class_for_schema({'type' => 'array'}).new(JSI::JSON::Node.new_doc(['a', 'b'])).as_json)
      assert_equal(['a'], JSI.class_for_schema({}).new(['a']).as_json(some_option: true))
    end
  end
  describe 'overwrite schema instance with instance=' do
    # this error message indicates an internal bug (hence Bug class), so there isn't an intended way to
    # trigger it using JSI::Base properly. we use it improperly just to test that code path. this
    # is definitely not defined behavior.
    it 'errors' do
      err = assert_raises(JSI::Bug) { subject.send(:instance=, {'foo' => 'bar'}) }
      assert_match(%r(\Aoverwriting instance is not supported\z), err.message)
    end
  end
end
