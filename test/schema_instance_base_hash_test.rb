require_relative 'test_helper'

describe Scorpio::SchemaInstanceBaseHash do
  let(:document) do
    {'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => true}
  end
  let(:path) { [] }
  let(:instance) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) do
    {
      'type' => 'object',
      'properties' => {
        'foo' => {'type' => 'object'},
        'bar' => {},
      },
    }
  end
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:class_for_schema) { Scorpio.class_for_schema(schema) }
  let(:subject) { class_for_schema.new(instance) }

  describe 'hashlike []=' do
    it 'sets a property' do
      orig_foo = subject['foo']

      subject['foo'] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject['foo'].as_json)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), orig_foo)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject['foo'])
    end
    it 'sets a property to a schema instance with a different schema' do
      orig_foo = subject['foo']

      subject['foo'] = subject['bar']

      # the content of the subscripts' instances is the same but the subscripts' classes are different
      assert_equal([9], subject['foo'].as_json)
      assert_equal([9], subject['bar'].as_json)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject['foo'])
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['bar']), subject['bar'])
    end
    it 'sets a property to a schema instance with the same schema' do
      other_subject = class_for_schema.new(Scorpio::JSON::Node.new_by_type({'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => true}, []))
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
      orig_instance = subject.instance

      subject['foo'] = {'y' => 'z'}

      assert_equal(orig_instance, subject.instance)
      assert_equal({'y' => 'z'}, orig_instance['foo'].as_json)
      assert_equal({'y' => 'z'}, subject.instance['foo'].as_json)
      assert_equal(orig_instance.class, subject.instance.class)
    end
    describe 'when the instance is not hashlike' do
      let(:instance) { nil }
      it 'errors' do
        err = assert_raises(NoMethodError) { subject['foo'] = 0 }
        assert_match(%r(\Aundefined method `\[\]=' for #<Scorpio::SchemaClasses::.*>\z), err.message)
      end
    end
  end
  # these methods just delegate to Hash so not going to test excessively
  describe 'key only methods' do
    it('#each_key') { assert_equal(['foo', 'bar', 'baz'], subject.each_key.to_a) }
    it('#empty?')   { assert_equal(false, subject.empty?) }
    it('#has_key?') { assert_equal(true, subject.has_key?('bar')) }
    it('#include?') { assert_equal(false, subject.include?('q')) }
    it('#key?')     { assert_equal(true, subject.key?('baz')) }
    it('#keys')     { assert_equal(['foo', 'bar', 'baz'], subject.keys) }
    it('#length')   { assert_equal(3, subject.length) }
    it('#member?')  { assert_equal(false, subject.member?(0)) }
    it('#size')     { assert_equal(3, subject.size) }
  end
  describe 'key + value methods' do
    it('#<')            { assert_equal(true, subject < {'foo' => subject['foo'], 'bar' => subject['bar'], 'baz' => true, 'x' => 'y'}) } if {}.respond_to?(:<)
    it('#<=')           { assert_equal(true, subject <= subject) } if {}.respond_to?(:<=)
    it('#>')            { assert_equal(true, subject > {}) } if {}.respond_to?(:>)
    it('#>=')           { assert_equal(false, subject >= {'foo' => 'bar'}) } if {}.respond_to?(:>=)
    it('#any?')         { assert_equal(false, subject.any? { |k, v| v == 3 }) }
    it('#assoc')        { assert_equal(['foo', subject['foo']], subject.assoc('foo')) }
    it('#dig')          { assert_equal(9, subject.dig('bar', 0)) } if {}.respond_to?(:dig)
    it('#each_pair')    { assert_equal([['foo', subject['foo']], ['bar', subject['bar']], ['baz', true]], subject.each_pair.to_a) }
    it('#each_value')   { assert_equal([subject['foo'], subject['bar'], true], subject.each_value.to_a) }
    it('#fetch')        { assert_equal(true, subject.fetch('baz')) }
    it('#fetch_values') { assert_equal([true], subject.fetch_values('baz')) } if {}.respond_to?(:fetch_values)
    it('#has_value?')   { assert_equal(true, subject.has_value?(true)) }
    it('#invert')       { assert_equal({subject['foo'] => 'foo', subject['bar'] => 'bar', true => 'baz'}, subject.invert) }
    it('#key')          { assert_equal('baz', subject.key(true)) }
    it('#rassoc')       { assert_equal(['baz', true], subject.rassoc(true)) }
    it('#to_h')         { assert_equal({'foo' => subject['foo'], 'bar' => subject['bar'], 'baz' => true}, subject.to_h) }
    it('#to_proc')      { assert_equal(true, subject.to_proc.call('baz')) } if {}.respond_to?(:to_proc)
    if {}.respond_to?(:transform_values)
      it('#transform_values') { assert_equal({'foo' => nil, 'bar' => nil, 'baz' => nil}, subject.transform_values { |_| nil}) }
    end
    it('#value?')       { assert_equal(false, subject.value?('0')) }
    it('#values')       { assert_equal([subject['foo'], subject['bar'], true], subject.values) }
    it('#values_at')    { assert_equal([true], subject.values_at('baz')) }
  end
  describe 'modified copy methods' do
    # I'm going to rely on the #merge test above to test the modified copy functionality and just do basic
    # tests of all the modified copy methods here
    it('#merge')            { assert_equal(subject, subject.merge({})) }
    it('#reject')           { assert_equal(class_for_schema.new(Scorpio::JSON::HashNode.new({}, [])), subject.reject { true }) }
    it('#select')           { assert_equal(class_for_schema.new(Scorpio::JSON::HashNode.new({}, [])), subject.select { false }) }
    describe '#select' do
      it 'yields properly too' do
        subject.select do |k, v|
          assert_equal(subject[k], v)
        end
      end
    end
    # Hash#compact only available as of ruby 2.5.0
    if {}.respond_to?(:compact)
      it('#compact')        { assert_equal(subject, subject.compact) }
    end
  end
  Scorpio::Hashlike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!subject.respond_to?(destructive_method_name))
    end
  end
end
