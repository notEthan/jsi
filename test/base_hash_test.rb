require_relative 'test_helper'

base = {
  'description' => 'named hash schema',
  'type' => 'object',
  'properties' => {
    'foo' => {'type' => 'object'},
    'bar' => {},
  },
}
NamedHashInstance = JSI::Schema.new(base).jsi_schema_class
NamedIdHashInstance = JSI::Schema.new({'$id' => 'https://schemas.jsi.unth.net/test/base/named_hash_schema'}.merge(base)).jsi_schema_class

describe 'JSI::Base hash' do
  let(:instance) { {'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => [true]} }
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
  let(:schema) { JSI::Schema.new(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  describe '#[] with a schema default that is a basic type' do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'default' => 'foo'},
        },
      }
    end
    describe 'default value' do
      let(:instance) { {'bar' => 3} }
      it 'returns the default value' do
        assert_equal('foo', subject.foo)
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { {'foo' => 'who'} }
      it 'returns the nondefault value' do
        assert_equal('who', subject.foo)
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { {'foo' => [2]} }
      it 'returns the nondefault value' do
        assert_is_a(schema.properties['foo'].jsi_schema_module, subject.foo)
        assert_equal([2], subject.foo.as_json)
      end
    end
  end
  describe '#[] with a schema default that is a nonbasic type' do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'default' => {'foo' => 2}},
        },
      }
    end
    describe 'default value' do
      let(:instance) { {'bar' => 3} }
      it 'returns the default value' do
        assert_is_a(schema.properties['foo'].jsi_schema_module, subject.foo)
        assert_equal({'foo' => 2}, subject.foo.as_json)
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { {'foo' => 'who'} }
      it 'returns the nondefault value' do
        assert_equal('who', subject.foo)
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { {'foo' => [2]} }
      it 'returns the nondefault value' do
        assert_is_a(schema.properties['foo'].jsi_schema_module, subject.foo)
        assert_equal([2], subject.foo.as_json)
      end
    end
  end
  describe '#[] with a hash default that is a nonbasic type' do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {},
        },
      }
    end
    describe 'default value' do
      let(:instance) { Hash.new({'foo' => 2}).merge({'bar' => 3}) }
      it 'returns the default value' do
        assert_is_a(Hash, subject.foo)
        assert_equal({'foo' => 2}, subject.foo)
      end
    end
  end
  describe 'hashlike []=' do
    it 'sets a property' do
      orig_foo = subject['foo']

      subject['foo'] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject['foo'].as_json)
      assert_is_a(schema.properties['foo'].jsi_schema_module, orig_foo)
      assert_is_a(schema.properties['foo'].jsi_schema_module, subject['foo'])
    end
    it 'sets a property to a schema instance with a different schema' do
      assert(subject['foo'])

      subject['foo'] = subject['bar']

      # the content of the subscripts' instances is the same but the subscripts' classes are different
      assert_equal([9], subject['foo'].as_json)
      assert_equal([9], subject['bar'].as_json)
      assert_is_a(schema.properties['foo'].jsi_schema_module, subject['foo'])
      assert_is_a(schema.properties['bar'].jsi_schema_module, subject['bar'])
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
        err = assert_raises(NoMethodError) { subject['foo'] = 0 }
        assert_equal('cannot assign subcript (using token: "foo") to instance: nil', err.message)
      end
    end
    describe '#inspect' do
      it 'inspects' do
        assert_equal("\#{<JSI> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print' do
      it 'pretty_prints' do
        assert_equal("\#{<JSI> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect SortOfHash' do
      let(:subject) { schema.new_jsi(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<JSI SortOfHash> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print SortOfHash' do
      let(:subject) { schema.new_jsi(SortOfHash.new(instance)) }
      it 'pretty_prints' do
        assert_equal("\#{<JSI SortOfHash>\n  \"foo\" => \#{<JSI> \"x\" => \"y\"},\n  \"bar\" => #[<JSI> 9],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named' do
      let(:subject) { NamedHashInstance.new(instance) }
      it 'inspects' do
        assert_equal("\#{<NamedHashInstance> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print named' do
      let(:subject) { NamedHashInstance.new(instance) }
      it 'inspects' do
        assert_equal("\#{<NamedHashInstance>\n  \"foo\" => \#{<JSI> \"x\" => \"y\"},\n  \"bar\" => #[<JSI> 9],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named SortOfHash' do
      let(:subject) { NamedHashInstance.new(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<NamedHashInstance SortOfHash> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print named SortOfHash' do
      let(:subject) { NamedHashInstance.new(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<NamedHashInstance SortOfHash>\n  \"foo\" => \#{<JSI> \"x\" => \"y\"},\n  \"bar\" => #[<JSI> 9],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named with id' do
      let(:subject) { NamedIdHashInstance.new(instance) }
      it 'inspects' do
        assert_equal("\#{<NamedIdHashInstance> \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/bar)> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print named with id' do
      let(:subject) { NamedIdHashInstance.new(instance) }
      it 'inspects' do
        assert_equal("\#{<NamedIdHashInstance>\n  \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/foo)>\n    \"x\" => \"y\"\n  },\n  \"bar\" => #[<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/bar)>\n    9\n  ],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named SortOfHash with id' do
      let(:subject) { NamedIdHashInstance.new(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<NamedIdHashInstance SortOfHash> \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/bar)> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print named with id SortOfHash' do
      let(:subject) { NamedIdHashInstance.new(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<NamedIdHashInstance SortOfHash>\n  \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/foo)>\n    \"x\" => \"y\"\n  },\n  \"bar\" => #[<JSI (https://schemas.jsi.unth.net/test/base/named_hash_schema#/properties/bar)>\n    9\n  ],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect with id' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/base_hash_test/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:subject) { schema.new_jsi(instance) }
      it 'inspects' do
        assert_equal("\#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#)> \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/bar)> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print with id' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/base_hash_test/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:subject) { schema.new_jsi(instance) }
      it 'inspects' do
        assert_equal("\#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#)>\n  \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/foo)>\n    \"x\" => \"y\"\n  },\n  \"bar\" => #[<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/bar)>\n    9\n  ],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect with id SortOfHash' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/base_hash_test/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:subject) { schema.new_jsi(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#) SortOfHash> \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/foo)> \"x\" => \"y\"}, \"bar\" => #[<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/bar)> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print with id SortOfHash' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/base_hash_test/withid', 'properties' => {'foo' => {}, 'bar' => {}}} }
      let(:subject) { schema.new_jsi(SortOfHash.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#) SortOfHash>\n  \"foo\" => \#{<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/foo)>\n    \"x\" => \"y\"\n  },\n  \"bar\" => #[<JSI (https://schemas.jsi.unth.net/base_hash_test/withid#/properties/bar)>\n    9\n  ],\n  \"baz\" => [true]\n}\n", subject.pretty_inspect)
      end
    end
    describe '#inspect jsi_object_group_text' do
      let(:instance_class) { Class.new(SortOfHash) { define_method(:jsi_object_group_text) { ['☺'] } } }
      let(:subject) { schema.new_jsi(instance_class.new(instance)) }
      it 'inspects' do
        assert_equal("\#{<JSI ☺> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}", subject.inspect)
      end
    end
    describe '#pretty_print jsi_object_group_text' do
      let(:instance_class) { Class.new(SortOfHash) { define_method(:jsi_object_group_text) { ['☺'] } } }
      let(:subject) { schema.new_jsi(instance_class.new(instance)) }
      it 'pretty_prints' do
        assert_equal("\#{<JSI ☺> \"foo\" => \#{<JSI> \"x\" => \"y\"}, \"bar\" => #[<JSI> 9], \"baz\" => [true]}\n", subject.pretty_inspect)
      end
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
    it('#each_pair') { assert_equal([['foo', subject['foo']], ['bar', subject['bar']], ['baz', [true]]], subject.each_pair.to_a) }
    it('#each_value') { assert_equal([subject['foo'], subject['bar'], [true]], subject.each_value.to_a) }
    it('#fetch')       { assert_equal([true], subject.fetch('baz')) }
    it('#fetch_values') { assert_equal([[true]], subject.fetch_values('baz')) } if {}.respond_to?(:fetch_values)
    it('#has_value?')  { assert_equal(true, subject.has_value?([true])) }
    it('#invert')     { assert_equal({subject['foo'] => 'foo', subject['bar'] => 'bar', [true] => 'baz'}, subject.invert) }
    it('#key')       { assert_equal('baz', subject.key([true])) }
    it('#rassoc')   { assert_equal(['baz', [true]], subject.rassoc([true])) }
    it('#to_h')    { assert_equal({'foo' => subject['foo'], 'bar' => subject['bar'], 'baz' => [true]}, subject.to_h) }
    it('#to_proc') { assert_equal([true], subject.to_proc.call('baz')) } if {}.respond_to?(:to_proc)
    if {}.respond_to?(:transform_values)
      it('#transform_values') { assert_equal({'foo' => nil, 'bar' => nil, 'baz' => nil}, subject.transform_values { |_| nil }) }
    end
    it('#value?')  { assert_equal(false, subject.value?('0')) }
    it('#values')   { assert_equal([subject['foo'], subject['bar'], [true]], subject.values) }
    it('#values_at') { assert_equal([[true]], subject.values_at('baz')) }
  end
  describe 'with an instance that has to_hash but not other hash instance methods' do
    let(:instance) { SortOfHash.new({'foo' => SortOfHash.new({'a' => 'b'})}) }
    describe 'delegating instance methods to #to_hash' do
      it('#each_key') { assert_equal(['foo'], subject.each_key.to_a) }
      it('#each_pair') { assert_equal([['foo', subject['foo']]], subject.each_pair.to_a) }
      it('#[]')       { assert_equal(SortOfHash.new({'a' => 'b'}), subject['foo'].jsi_instance) }
      it('#as_json') { assert_equal({'foo' => {'a' => 'b'}}, subject.as_json) }
    end
  end
  describe 'modified copy methods' do
    # I'm going to rely on the #merge test above to test the modified copy functionality and just do basic
    # tests of all the modified copy methods here
    it('#merge') { assert_equal(subject, subject.merge({})) }
    it('#reject') { assert_equal(schema.new_jsi({}), subject.reject { true }) }
    it('#select') { assert_equal(schema.new_jsi({}), subject.select { false }) }
    describe '#select' do
      it 'yields properly too' do
        subject.select do |k, v|
          assert_equal(subject[k], v)
        end
      end
    end
    # Hash#compact only available as of ruby 2.5.0
    if {}.respond_to?(:compact)
      it('#compact') { assert_equal(subject, subject.compact) }
    end
  end
  JSI::Hashlike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!subject.respond_to?(destructive_method_name))
    end
  end
end
