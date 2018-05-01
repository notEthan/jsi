require_relative 'test_helper'

describe Scorpio::SchemaObjectBaseHash do
  let(:document) do
    {'foo' => {'x' => 'y'}, 'bar' => [9], 'baz' => true}
  end
  let(:path) { [] }
  let(:object) { Scorpio::JSON::Node.new_by_type(document, path) }
  let(:schema_content) do
    {
      'type' => 'object',
      'properties' => {
        'foo' => {'type' => 'object'},
      },
    }
  end
  let(:schema) { Scorpio::Schema.new(schema_content) }
  let(:class_for_schema) { Scorpio.class_for_schema(schema) }
  let(:subject) { class_for_schema.new(object) }

  describe 'hashlike []=' do
    it 'sets a property' do
      orig_foo = subject['foo']

      subject['foo'] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject['foo'].as_json)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), orig_foo)
      assert_instance_of(Scorpio.class_for_schema(schema.schema_node['properties']['foo']), subject['foo'])
    end
    it 'updates to a modified copy of the object without altering the original' do
      orig_object = subject.object

      subject['foo'] = {'y' => 'z'}

      refute_equal(orig_object, subject.object)
      assert_equal({'x' => 'y'}, orig_object['foo'].as_json)
      assert_equal({'y' => 'z'}, subject.object['foo'].as_json)
      assert_equal(orig_object.class, subject.object.class)
    end
    describe 'when the object is not hashlike' do
      let(:object) { nil }
      it 'errors' do
        err = assert_raises(NoMethodError) { subject['foo'] = 0 }
        assert_match(%r(\Aundefined method `\[\]=' for #<Scorpio::SchemaClasses::X.*>\z), err.message)
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
    it('#value?')       { assert_equal(false, subject.value?('0')) }
    it('#values')       { assert_equal([subject['foo'], subject['bar'], true], subject.values) }
    it('#values_at')    { assert_equal([true], subject.values_at('baz')) }
  end
  describe 'modified copy methods' do
    # I'm going to rely on the #merge test above to test the modified copy functionality and just do basic
    # tests of all the modified copy methods here
    it('#merge')            { assert_equal(subject, subject.merge({})) }
    it('#transform_values') { assert_equal(class_for_schema.new(Scorpio::JSON::HashNode.new({'foo' => nil, 'bar' => nil, 'baz' => nil}, [])), subject.transform_values { |_| nil}) }
    it('#reject')           { assert_equal(class_for_schema.new(Scorpio::JSON::HashNode.new({}, [])), subject.reject { true }) }
    it('#select')           { assert_equal(class_for_schema.new(Scorpio::JSON::HashNode.new({}, [])), subject.select { false }) }
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
