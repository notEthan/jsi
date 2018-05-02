require_relative 'test_helper'

describe Scorpio::SchemaObjectBase do
  let(:document) { {} }
  let(:path) { [] }
  let(:object) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) { {} }
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:subject) { Scorpio.class_for_schema(schema).new(object) }
  describe 'class .inspect' do
    it 'is the same as Class#inspect on the base' do
      assert_equal('Scorpio::SchemaObjectBase', Scorpio::SchemaObjectBase.inspect)
    end
    it 'is SchemaClasses[] for generated subclass without id' do
      assert_match(%r(\AScorpio::SchemaClasses\["[a-f0-9\-]+#"\]\z), subject.class.inspect)
    end
    describe 'with schema id' do
      let(:schema_content) { {'id' => 'https://scorpio/foo'} }
      it 'is SchemaClasses[] for generated subclass with id' do
        assert_equal(%q(Scorpio::SchemaClasses["https://scorpio/foo#"]), subject.class.inspect)
      end
    end
  end
  describe 'class for schema .schema' do
    it '.schema' do
      assert_equal(schema, Scorpio.class_for_schema(schema).schema)
    end
  end
  describe 'class for schema .schema_id' do
    it '.schema_id' do
      assert_equal(schema.schema_id, Scorpio.class_for_schema(schema).schema_id)
    end
  end
  describe 'module for schema .inspect' do
    it '.inspect' do
      assert_match(%r(\A#<Module for Schema: .+#>\z), Scorpio.module_for_schema(schema).inspect)
    end
  end
  describe 'module for schema .schema' do
    it '.schema' do
      assert_equal(schema, Scorpio.module_for_schema(schema).schema)
    end
  end
  describe 'SchemaClasses[]' do
    it 'stores the class for the schema' do
      assert_equal(Scorpio.class_for_schema(schema), Scorpio::SchemaClasses[schema.schema_id])
    end
  end
  describe '.class_for_schema' do
    it 'returns a class from a schema' do
      class_for_schema = Scorpio.class_for_schema(schema)
      # same class every time
      assert_equal(Scorpio.class_for_schema(schema), class_for_schema)
      assert_operator(class_for_schema, :<, Scorpio::SchemaObjectBase)
    end
    it 'returns a class from a hash' do
      assert_equal(Scorpio.class_for_schema(schema), Scorpio.class_for_schema(schema.schema_node.content))
    end
    it 'returns a class from a schema node' do
      assert_equal(Scorpio.class_for_schema(schema), Scorpio.class_for_schema(schema.schema_node))
    end
    it 'returns a class from a SchemaObjectBase' do
      assert_equal(Scorpio.class_for_schema(schema), Scorpio.class_for_schema(Scorpio.class_for_schema({}).new(schema.schema_node)))
    end
  end
  describe '.module_for_schema' do
    it 'returns a module from a schema' do
      module_for_schema = Scorpio.module_for_schema(schema)
      # same module every time
      assert_equal(Scorpio.module_for_schema(schema), module_for_schema)
    end
    it 'returns a module from a hash' do
      assert_equal(Scorpio.module_for_schema(schema), Scorpio.module_for_schema(schema.schema_node.content))
    end
    it 'returns a module from a schema node' do
      assert_equal(Scorpio.module_for_schema(schema), Scorpio.module_for_schema(schema.schema_node))
    end
    it 'returns a module from a SchemaObjectBase' do
      assert_equal(Scorpio.module_for_schema(schema), Scorpio.module_for_schema(Scorpio.class_for_schema({}).new(schema.schema_node)))
    end
  end
  describe 'initialization' do
    describe 'nil' do
      let(:object) { nil }
      it 'initializes with nil object' do
        assert_equal(Scorpio::JSON::Node.new_by_type(nil, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary object' do
      let(:object) { Object.new }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type(object, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:object) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type({'foo' => 'bar'}, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'Scorpio::JSON::Hashnode' do
      let(:document) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::HashNode.new({'foo' => 'bar'}, []), subject.object)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'array' do
      let(:object) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::Node.new_by_type(['foo'], []), subject.object)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'Scorpio::JSON::Arraynode' do
      let(:document) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(Scorpio::JSON::ArrayNode.new(['foo'], []), subject.object)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
  end
  describe '#modified_copy' do
    describe 'with an object that does have #modified_copy' do
      it 'yields the object to modify' do
        modified = subject.modified_copy do |o|
          assert_equal({}, o)
          {'a' => 'b'}
        end
        assert_equal({'a' => 'b'}, modified.object.content)
        assert_equal({}, subject.object.content)
        refute_equal(object, modified)
      end
    end
    describe 'no modification' do
      it 'yields the object to modify' do
        modified = subject.modified_copy { |o| o }
        # this doesn't really need to be tested but ... whatever
        assert_equal(subject.object.content.object_id, modified.object.content.object_id)
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
        assert_equal('{}', modified.object.content)
        assert_equal({}, subject.object.content)
        refute_equal(object, modified)
        # interesting side effect
        assert(subject.respond_to?(:to_hash))
        assert(!modified.respond_to?(:to_hash))
        assert_equal(Scorpio::JSON::HashNode, subject.object.class)
        assert_equal(Scorpio::JSON::Node, modified.object.class)
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
        assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject.foo)
        assert_respond_to(subject.foo, :to_hash)
        refute_respond_to(subject.foo, :to_ary)
        assert_equal([3.14159], subject.bar.as_json)
        assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['bar']), subject.bar)
        refute_respond_to(subject.bar, :to_hash)
        assert_respond_to(subject.bar, :to_ary)
        assert_equal(true, subject.baz)
        refute_respond_to(subject.baz, :to_hash)
        refute_respond_to(subject.baz, :to_ary)
        refute_respond_to(subject, :qux)
      end
      describe 'when the object is not hashlike' do
        let(:object) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo }
          assert_match(%r(\Aobject does not respond to \[\]; cannot call reader `foo' for: #<Scorpio::SchemaClasses\["[^"]+#"\].*nil.*>\z)m, err.message)
        end
      end
    end
    describe 'writers' do
      it 'writes attributes describes as properties' do
        orig_foo = subject.foo

        subject.foo = {'y' => 'z'}

        assert_equal({'y' => 'z'}, subject.foo.as_json)
        assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), orig_foo)
        assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject.foo)
      end
      it 'updates to a modified copy of the object without altering the original' do
        orig_object = subject.object

        subject.foo = {'y' => 'z'}

        refute_equal(orig_object, subject.object)
        assert_equal({'x' => 'y'}, orig_object['foo'].as_json)
        assert_equal({'y' => 'z'}, subject.object['foo'].as_json)
        assert_equal(orig_object.class, subject.object.class)
      end
      describe 'when the object is not hashlike' do
        let(:object) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo = 0 }
          assert_match(%r(\Aobject does not respond to \[\]=; cannot call writer `foo=' for: #<Scorpio::SchemaClasses\["[^"]+#"\].*nil.*>\z)m, err.message)
        end
      end
    end
  end
  describe '#inspect' do
    it 'inspects' do
      assert_match(%r(\A#<Scorpio::SchemaClasses\["[^"]+#"\] #\{<Scorpio::JSON::HashNode fragment="#">\}>\z), subject.inspect)
    end
  end
  describe '#pretty_print' do
    it 'pretty_prints' do
      assert_match(%r(\A#<Scorpio::SchemaClasses\["[^"]+#"\]\n  #\{<Scorpio::JSON::HashNode fragment="#">\}\n>\z), subject.pretty_inspect.chomp)
    end
  end
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema({}).new(Scorpio::JSON::Node.new_by_type({'a' => 'b'}, [])).as_json)
      assert_equal({'a' => 'b'}, Scorpio.class_for_schema({'type' => 'object'}).new(Scorpio::JSON::Node.new_by_type({'a' => 'b'}, [])).as_json)
      assert_equal(['a', 'b'], Scorpio.class_for_schema({'type' => 'array'}).new(Scorpio::JSON::Node.new_by_type(['a', 'b'], [])).as_json)
    end
  end
end
