require_relative 'test_helper'

describe 'JSI::Base hash' do
  let(:default_instance) { {'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => [true]} }
  let(:instance) { default_instance }
  let(:schema_content) do
    {
      'description' => 'hash schema',
      'type' => 'object',
      'properties' => {
        'foo' => {'type' => 'object'},
        'bar' => {},
      },
    }
  end
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07) }
  let(:subject_opt) { {} }
  let(:subject) { schema.new_jsi(instance, **subject_opt) }

  describe("#[] with a schema default that is a simple type") do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'default' => 'foo'},
        },
      }
    end

    schema_instance_child_use_default_default_true

    describe 'default value' do
      let(:instance) { {'bar' => 3} }
      it 'returns the default value' do
        assert_equal('foo', subject.foo)
        assert_nil(subject.foo(use_default: false))
      end
    end
    describe("nondefault value (simple type)") do
      let(:instance) { {'foo' => 'who'} }
      it 'returns the nondefault value' do
        assert_equal('who', subject.foo)
        assert_equal('who', subject.foo(use_default: false))
      end
    end
    describe("nondefault value (complex type)") do
      let(:instance) { {'foo' => [2]} }
      it 'returns the nondefault value' do
        assert_schemas([schema.properties['foo']], subject.foo)
        assert_equal([2], subject.foo.jsi_instance)
      end
    end
  end
  describe("#[] with a schema default that is a complex type") do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'default' => {'foo' => 2}},
        },
      }
    end

    schema_instance_child_use_default_default_true

    describe 'default value' do
      let(:instance) { {'bar' => 3} }
      it 'returns the default value' do
        assert_schemas([schema.properties['foo']], subject.foo)
        assert_nil(subject.foo(use_default: false))
        assert_equal({'foo' => 2}, subject.foo.jsi_instance)
      end
    end
    describe("nondefault value (simple type)") do
      let(:instance) { {'foo' => 'who'} }
      it 'returns the nondefault value' do
        assert_equal('who', subject.foo)
        assert_equal('who', subject.foo(use_default: false))
      end
    end
    describe("nondefault value (complex type)") do
      let(:instance) { {'foo' => [2]} }
      it 'returns the nondefault value' do
        assert_schemas([schema.properties['foo']], subject.foo)
        assert_equal([2], subject.foo.jsi_instance)
      end
    end
  end
  describe("#[] with a hash default that is a complex type") do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {},
        },
      }
    end

    schema_instance_child_use_default_default_true

    describe 'default value' do
      let(:instance) { Hash.new({'foo' => 2}).merge({'bar' => 3}) }
      it 'returns the default value' do
        assert_is_a(Hash, subject.foo)
        assert_equal({'foo' => 2}, subject.foo)
      end
    end
  end
  describe 'hashlike []=' do
    let(:subject_opt) { {mutable: true} }

    it 'sets a property' do
      orig_foo = subject['foo']

      subject['foo'] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject['foo'].jsi_instance)
      assert_schemas([schema.properties['foo']], orig_foo)
      assert_schemas([schema.properties['foo']], subject['foo'])
    end
    it 'sets a property to a schema instance with a different schema' do
      assert(subject['foo'])

      subject['foo'] = subject['bar']

      # the content of the subscripts' instances is the same but the subscripts' classes are different
      assert_equal([9], subject['foo'].jsi_instance)
      assert_equal([9], subject['bar'].jsi_instance)
      assert_schemas([schema.properties['foo']], subject['foo'])
      assert_schemas([schema.properties['bar']], subject['bar'])
    end
    it 'sets a property to a schema instance with the same schema' do
      other_subject = schema.new_jsi({'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => [true]})
      # Given
      assert_equal(other_subject, subject)

      # When:
      subject['foo'] = other_subject['foo']

      # Then:
      # still equal
      assert_equal(other_subject, subject)
      # but different instances
      refute_equal(other_subject['foo'].object_id, subject['foo'].object_id)
    end
    it 'modifies the instance, visible to other references to the same instance' do
      orig_instance = subject.jsi_instance

      subject['foo'] = {'y' => 'z'}

      assert_equal(orig_instance, subject.jsi_instance)
      assert_equal({'y' => 'z'}, orig_instance['foo'])
      assert_equal({'y' => 'z'}, subject.jsi_instance['foo'])
      assert_equal(orig_instance.class, subject.jsi_instance.class)
    end
    describe 'when the instance is not hashlike' do
      let(:instance) { nil }
      it 'errors' do
        err = assert_raises(JSI::Base::SimpleNodeChildError) { subject['foo'] = 0 }
        assert_equal(%Q(cannot access a child of this JSI node because this node is not complex\nusing token: "foo"\ninstance: nil), err.message)
      end
    end
    describe '#inspect, #to_s' do
      it 'inspects' do
        assert_equal("\#{<JSI*1> \"foo\" => \#{<JSI*1> \"x\" => \"y\"}, \"bar\" => #[<JSI*1> 9], \"baz\" => #[<JSI*0> true]}", subject.inspect)
        assert_equal(subject.inspect, subject.to_s)
      end
    end
    describe '#pretty_print' do
      it 'pretty prints' do
        pp = <<~PP
          \#{<JSI*1>
            "foo" => \#{<JSI*1> "x" => "y"},
            "bar" => #[<JSI*1> 9],
            "baz" => #[<JSI*0> true]
          }
          PP
        assert_equal(pp, subject.pretty_inspect)
      end

      describe 'with a long module name' do
        HashSchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines = JSI::JSONSchemaDraft07.new_schema_module({"$id": "jsi:2be2"})
        it 'does not break empty hash' do
          subject = HashSchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines.new_jsi({})
          pp = %Q(\#{<JSI (HashSchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines)>}\n)
          assert_equal(pp, subject.pretty_inspect)
        end
      end
    end
    describe '#inspect SortOfHash' do
      let(:instance) { SortOfHash.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'inspects' do
        assert_equal("\#{<JSI*1 SortOfHash> \"foo\" => \#{<JSI*1> \"x\" => \"y\"}, \"bar\" => #[<JSI*1> 9], \"baz\" => #[<JSI*0> true]}", subject.inspect)
      end
    end
    describe '#pretty_print SortOfHash' do
      let(:instance) { SortOfHash.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'pretty prints' do
        pp = <<~PP
          \#{<JSI*1 SortOfHash>
            "foo" => \#{<JSI*1> "x" => "y"},
            "bar" => #[<JSI*1> 9],
            "baz" => #[<JSI*0> true]
          }
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_hash/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      it 'inspects' do
        assert_equal("\#{<JSI (http://jsi/base_hash/withid)> \"foo\" => \#{<JSI (http://jsi/base_hash/withid#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (http://jsi/base_hash/withid#/properties/bar)> 9], \"baz\" => #[<JSI*0> true]}", subject.inspect)
      end
    end
    describe '#pretty_print with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_hash/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      it 'pretty prints' do
        pp = <<~PP
          \#{<JSI (http://jsi/base_hash/withid)>
            "foo" => \#{<JSI (http://jsi/base_hash/withid#/properties/foo)> "x" => "y"},
            "bar" => #[<JSI (http://jsi/base_hash/withid#/properties/bar)> 9],
            "baz" => #[<JSI*0> true]
          }
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id SortOfHash' do
      let(:schema_content) { {'$id' => 'http://jsi/base_hash/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:instance) { SortOfHash.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'inspects' do
        assert_equal("\#{<JSI (http://jsi/base_hash/withid) SortOfHash> \"foo\" => \#{<JSI (http://jsi/base_hash/withid#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (http://jsi/base_hash/withid#/properties/bar)> 9], \"baz\" => #[<JSI*0> true]}", subject.inspect)
      end
    end
    describe '#pretty_print with id SortOfHash' do
      let(:schema_content) { {'$id' => 'http://jsi/base_hash/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:instance) { SortOfHash.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'pretty prints' do
        pp = <<~PP
          \#{<JSI (http://jsi/base_hash/withid) SortOfHash>
            "foo" => \#{<JSI (http://jsi/base_hash/withid#/properties/foo)> "x" => "y"},
            "bar" => #[<JSI (http://jsi/base_hash/withid#/properties/bar)> 9],
            "baz" => #[<JSI*0> true]
          }
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect jsi_object_group_text' do
      let(:instance_class) { Class.new(SortOfHash) { define_method(:jsi_object_group_text) { ['☺'] } } }
      let(:instance) { instance_class.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'inspects' do
        assert_equal("\#{<JSI*1 ☺> \"foo\" => \#{<JSI*1> \"x\" => \"y\"}, \"bar\" => #[<JSI*1> 9], \"baz\" => #[<JSI*0> true]}", subject.inspect)
      end
    end
    describe '#pretty_print jsi_object_group_text' do
      let(:instance_class) { Class.new(SortOfHash) { define_method(:jsi_object_group_text) { ['☺'] } } }
      let(:instance) { instance_class.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'pretty prints' do
        pp = <<~PP
          \#{<JSI*1 ☺>
            "foo" => \#{<JSI*1> "x" => "y"},
            "bar" => #[<JSI*1> 9],
            "baz" => #[<JSI*0> true]
          }
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
  end

  describe 'jsi_each_propertyName' do
    describe 'valid and invalid propertyNames' do
      let(:schema_content) do
        {
          'allOf' => [
            {
              'propertyNames' => {
                'maxLength' => 3,
              },
            },
            {
              'propertyNames' => {
                'minLength' => 1,
              },
            },
            true, # does not apply but ensures jsi_each_propertyName doesn't choke on boolean schema
          ]
        }
      end

      let(:instance) { {'str' => [], 'longstr' => []} }

      it 'yields each as a jsi' do
        subject.jsi_each_propertyName do |propertyName|
          assert_schemas([schema.allOf[0].propertyNames, schema.allOf[1].propertyNames], propertyName)
        end
        jsis = %w(str longstr).map do |k|
          JSI::SchemaSet[
            schema.allOf[0].propertyNames,
            schema.allOf[1].propertyNames,
          ].new_jsi(k)
        end
        assert_equal(jsis, subject.jsi_each_propertyName.to_a)

        valid, invalid = subject.jsi_each_propertyName.partition(&:jsi_valid?)
        assert_equal(['str'], valid.map(&:jsi_instance))
        assert_equal(['longstr'], invalid.map(&:jsi_instance))
      end
    end

    describe 'no propertyNames schema' do
      # note: schema_content and instance not redefined from the top-level describe

      it 'yields each as a jsi' do
        subject.jsi_each_propertyName do |propertyName|
          assert_schemas([], propertyName)
          assert(propertyName.jsi_valid?)
        end

        assert_equal(%w(foo bar baz).map { |k| JSI::SchemaSet[].new_jsi(k) }, subject.jsi_each_propertyName.to_a)
        assert(subject.jsi_each_propertyName.all?(&:jsi_valid?))
      end
    end

    describe "when a schema's `propertyNames` is not a schema" do
      let(:schema) do
        JSI.new_metaschema({}, dialect: JSI::Schema::Dialect.new(
          vocabularies: [
            JSI::Schema::Vocabulary.new(elements: [
              JSI::Schema::Elements::SELF[],
            ]),
          ],
        )).new_schema({'propertyNames' => {}})
      end

      it 'applies no propertyNames schemas' do
        assert_schemas([], schema['propertyNames']) # not what we're testing, just checking propertyNames isn't a schema
        assert_equal(%w(foo bar baz).map { |k| JSI::SchemaSet[].new_jsi(k) }, subject.jsi_each_propertyName.to_a)
        assert(subject.jsi_each_propertyName.all?(&:jsi_valid?))
      end
    end
  end

  describe 'each' do
    it 'yields each element' do
      expect_modules = [schema.properties['foo'].jsi_schema_module, schema.properties['bar'].jsi_schema_module, JSI::Base::ArrayNode]
      subject.each { |_, v| assert_is_a(expect_modules.shift, v) }
    end
    it 'yields each element as_jsi' do
      expect_schemas = [[schema.properties['foo']], [schema.properties['bar']], []]
      subject.each(as_jsi: true) { |_, v| assert_schemas(expect_schemas.shift, v) }
    end

    it 'gives the right number of arguments to proc and lambda' do
      res = []
      blocks = [
        proc   { |k, v| res << [k, v] },
        proc   { |a|    res << a },
        lambda { |k, v| res << [k, v] },
        lambda { |a|    res << a },
        -> (k, v) {     res << [k, v] }, # -> is the same as lambda, so this is redundant, but w/e
        -> (a) {        res << a },
      ]
      # none of these raise ArgumentError: wrong number of arguments
      blocks.each { |blk| subject.each(&blk) }
      assert_equal(%w(foo bar baz).map { |k| [k, subject[k]] } * blocks.size, res)
    end
  end
  describe 'to_hash' do
    it 'includes each element' do
      expect_modules = [schema.properties['foo'].jsi_schema_module, schema.properties['bar'].jsi_schema_module, JSI::Base::ArrayNode]
      subject.to_hash.each { |_, v| assert_is_a(expect_modules.shift, v) }
    end
    it 'includes each element as_jsi' do
      expect_schemas = [[schema.properties['foo']], [schema.properties['bar']], []]
      subject.to_hash(as_jsi: true).each { |_, v| assert_schemas(expect_schemas.shift, v) }
    end
  end

  describe 'to_a' do
    it 'is an array' do
      expect_ary = [['foo', subject.foo], ['bar', subject.bar], ['baz', subject['baz']]]
      assert_equal(expect_ary, subject.to_a)
    end

    it 'is an array of keys + JSIs' do
      expect_ary = [['foo', subject.foo], ['bar', subject.bar], ['baz', subject['baz', as_jsi: true]]]
      assert_equal(expect_ary, subject.to_a(as_jsi: true))
    end
  end

  # these methods just delegate to Hash so not going to test excessively
  describe 'key only methods' do
    it('#each_key') { assert_equal(['foo', 'bar', 'baz'], subject.each_key.to_a) }
    it('#empty?')   { assert_equal(false, subject.empty?) }
    it('#has_key?') { assert_equal(true, subject.has_key?('bar')) }
    it('#include?') { assert_equal(false, subject.include?('q')) }
    it('#key?')    { assert_equal(true, subject.key?('baz')) }
    it('#keys')   { assert_equal(['foo', 'bar', 'baz'], subject.keys) }
    it('#length') { assert_equal(3, subject.length) }
    it('#member?') { assert_equal(false, subject.member?(0)) }
    it('#size')   { assert_equal(3, subject.size) }
  end
  describe 'key + value methods' do
    it('#<')  { assert_equal(true, subject < {'foo' => subject['foo'], 'bar' => subject['bar'], 'baz' => subject['baz'], 'x' => 'y'}) } if {}.respond_to?(:<)
    it('#<=')  { assert_equal(true, subject <= subject) } if {}.respond_to?(:<=)
    it('#>')    { assert_equal(true, subject > {}) } if {}.respond_to?(:>)
    it('#>=')    { assert_equal(false, subject >= {'foo' => 'bar'}) } if {}.respond_to?(:>=)
    it('#any?')   { assert_equal(false, subject.any? { |k, v| v == 3 }) }
    it('#assoc')   { assert_equal(['foo', subject['foo']], subject.assoc('foo')) }
    it('#dig')      { assert_equal(9, subject.dig('bar', 0)) } if {}.respond_to?(:dig)
    it('#each_pair') { assert_equal([['foo', subject['foo']], ['bar', subject['bar']], ['baz', subject['baz']]], subject.each_pair.to_a) }
    it('#each_value') { assert_equal([subject['foo'], subject['bar'], subject['baz']], subject.each_value.to_a) }
    it('#fetch')       { assert_equal(subject['baz'], subject.fetch('baz')) }
    it('#fetch_values') { assert_equal([subject['baz']], subject.fetch_values('baz')) } if {}.respond_to?(:fetch_values)
    it('#has_value?')  { assert_equal(true, subject.has_value?(subject['baz'])) }
    it('#invert')     { assert_equal({subject['foo'] => 'foo', subject['bar'] => 'bar', subject['baz'] => 'baz'}, subject.invert) }
    it('#key')       { assert_equal('baz', subject.key(subject['baz'])) }
    it('#rassoc')   { assert_equal(['baz', subject['baz']], subject.rassoc(subject['baz'])) }
    it('#to_h')    { assert_equal({'foo' => subject['foo'], 'bar' => subject['bar'], 'baz' => subject['baz']}, subject.to_h) }
    it('#to_proc') { assert_equal(subject['baz'], subject.to_proc.call('baz')) } if {}.respond_to?(:to_proc)
    if {}.respond_to?(:transform_values)
      it('#transform_values') { assert_equal({'foo' => nil, 'bar' => nil, 'baz' => nil}, subject.transform_values { |_| nil }) }
    end
    it('#value?')  { assert_equal(false, subject.value?('0')) }
    it('#values')   { assert_equal([subject['foo'], subject['bar'], subject['baz']], subject.values) }
    it('#values_at') { assert_equal([subject['baz']], subject.values_at('baz')) }
  end
  describe 'with an instance that has to_hash but not other hash instance methods' do
    let(:instance) { SortOfHash.new({'foo' => SortOfHash.new({'a' => 'b'})}) }
    let(:subject_opt) { {to_immutable: nil} }
    describe 'delegating instance methods to #to_hash' do
      it('#each_key') { assert_equal(['foo'], subject.each_key.to_a) }
      it('#each_pair') { assert_equal([['foo', subject['foo']]], subject.each_pair.to_a) }
      it('#[]')       { assert_equal(SortOfHash.new({'a' => 'b'}), subject['foo'].jsi_instance) }
      it('#as_json') { assert_equal({'foo' => {'a' => 'b'}}, subject.as_json) }
    end

    describe 'modified copy' do
      it 'modifies a copy' do
        modified_root = subject.foo.select { false }.jsi_root_node
        # modified_root instance ceases to be SortOfHash because SortOfHash has no #[]= method
        # modified_root.foo instance ceases to be SortOfHash because SortOfHash has no #select method
        assert_equal(schema.new_jsi({'foo' => {}}), modified_root)
      end
    end
  end
  describe 'modified copy methods' do
    it('#merge') { assert_equal(schema.new_jsi(instance.merge({'a' => ['b']})), subject.merge({'a' => ['b']})) }
    it('#merge Base') { assert_equal(schema.new_jsi(instance.merge({'a' => ['b']})), subject.merge(schema.new_jsi({'a' => ['b']}))) }
    it('#merge applied schemas') do
      schema = JSI::JSONSchemaDraft07.new_schema({anyOf: [{required: ["a"]}, {required: ["b"]}]})
      subject = schema.new_jsi({"a" => 0})
      assert_schemas([schema, schema.anyOf[0]], subject)
      merged = subject.merge({"b" => 1})
      assert_schemas([schema, schema.anyOf[0], schema.anyOf[1]], merged)
    end
    it('#reject') { assert_equal(schema.new_jsi({}), subject.reject { true }) }
    it('#select') { assert_equal(schema.new_jsi({}), subject.select { false }) }
    describe '#select' do
      it 'yields property too' do
        subject.select do |k, v|
          assert_equal(subject[k], v)
        end
      end
      it 'passes as_jsi' do
        result = subject.select(as_jsi: true) do |k, v|
          assert_equal(subject[k, as_jsi: true], v)
          v.jsi_schemas.empty?
        end
        assert_equal(schema.new_jsi({'baz' => [true]}), result)
      end
    end
    # Hash#compact only available as of ruby 2.5.0
    if {}.respond_to?(:compact)
      it('#compact') { assert_equal(subject, subject.compact) }
    end
  end
  JSI::Util::Hashlike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!subject.respond_to?(destructive_method_name))
    end
  end
end

$test_report_file_loaded[__FILE__]
