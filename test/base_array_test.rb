require_relative 'test_helper'

base = {
  'description' => 'named array schema',
  'type' => 'array',
  'items' => [
    {'type' => 'string'},
    {'type' => 'object'},
    {'type' => 'array', 'items' => {}},
  ],
}
NamedArrayInstance = JSI.class_for_schema(base)
NamedIdArrayInstance = JSI.class_for_schema({'$id' => 'https://schemas.jsi.unth.net/test/base/named_array_schema'}.merge(base))

describe JSI::BaseArray do
  let(:instance) { ['foo', {'lamp' => [3]}, ['q', 'r'], {'four' => 4}] }
  let(:schema_content) do
    {
      'description' => 'hash schema',
      'type' => 'array',
      'items' => [
        {'type' => 'string'},
        {'type' => 'object'},
        {'type' => 'array', 'items' => {}},
      ],
    }
  end
  let(:schema) { JSI::Schema.new(schema_content) }
  let(:subject) { schema.new_jsi(instance) }

  describe '#[] with a default that is a basic type' do
    let(:schema_content) do
      {
        'type' => 'array',
        'items' => {'default' => 'foo'},
      }
    end
    describe 'default value' do
      let(:instance) { [1] }
      it 'returns the default value' do
        assert_equal('foo', subject[2])
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { ['who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[0])
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { [[2]] }
      it 'returns the nondefault value' do
        assert_is_a(schema.items.jsi_schema_module, subject[0])
        assert_equal([2], subject[0].as_json)
      end
    end
  end
  describe '#[] with a default that is a nonbasic type' do
    let(:schema_content) do
      {
        'type' => 'array',
        'items' => {'default' => {'foo' => 2}},
      }
    end
    describe 'default value' do
      let(:instance) { [{'bar' => 3}] }
      it 'returns the default value' do
        assert_is_a(schema.items.jsi_schema_module, subject[1])
        assert_equal({'foo' => 2}, subject[1].as_json)
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { [true, 'who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[1])
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { [true, [2]] }
      it 'returns the nondefault value' do
        assert_is_a(schema.items.jsi_schema_module, subject[1])
        assert_equal([2], subject[1].as_json)
      end
    end
  end
  describe 'arraylike []=' do
    it 'sets an index' do
      orig_2 = subject[2]

      subject[2] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject[2].as_json)
      assert_is_a(schema.items[2].jsi_schema_module, orig_2)
      assert_is_a(schema.items[2].jsi_schema_module, subject[2])
    end
    it 'modifies the instance, visible to other references to the same instance' do
      orig_instance = subject.jsi_instance

      subject[2] = {'y' => 'z'}

      assert_equal(orig_instance, subject.jsi_instance)
      assert_equal({'y' => 'z'}, orig_instance[2])
      assert_equal({'y' => 'z'}, subject.jsi_instance[2])
      assert_equal(orig_instance.class, subject.jsi_instance.class)
    end
    describe 'when the instance is not arraylike' do
      let(:instance) { nil }
      it 'errors' do
        err = assert_raises(NoMethodError) { subject[2] = 0 }
        assert_equal("cannot assign subcript (using token: 2) to instance: nil", err.message)
      end
    end
    describe '#inspect' do
      it 'inspects' do
        assert_equal("#[<JSI> \"foo\", \#{<JSI> \"lamp\" => [3]}, #[<JSI> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print' do
      it 'pretty_prints' do
        assert_equal("#[<JSI> \"foo\", \#{<JSI> \"lamp\" => [3]}, #[<JSI> \"q\", \"r\"], {\"four\"=>4}]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect SortOfArray' do
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI SortOfArray> \"foo\", \#{<JSI> \"lamp\" => [3]}, #[<JSI> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print SortOfArray' do
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'pretty_prints' do
        assert_equal("#[<JSI SortOfArray>\n  \"foo\",\n  \#{<JSI> \"lamp\" => [3]},\n  #[<JSI> \"q\", \"r\"],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named' do
      let(:subject) { NamedArrayInstance.new(instance) }
      it 'inspects' do
        assert_equal("#[<NamedArrayInstance> \"foo\", \#{<JSI> \"lamp\" => [3]}, #[<JSI> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print named' do
      let(:subject) { NamedArrayInstance.new(instance) }
      it 'inspects' do
        assert_equal("#[<NamedArrayInstance>\n  \"foo\",\n  \#{<JSI> \"lamp\" => [3]},\n  #[<JSI> \"q\", \"r\"],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named SortOfArray' do
      let(:subject) { NamedArrayInstance.new(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<NamedArrayInstance SortOfArray> \"foo\", \#{<JSI> \"lamp\" => [3]}, #[<JSI> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print named SortOfArray' do
      let(:subject) { NamedArrayInstance.new(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<NamedArrayInstance SortOfArray>\n  \"foo\",\n  \#{<JSI> \"lamp\" => [3]},\n  #[<JSI> \"q\", \"r\"],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named with id' do
      let(:subject) { NamedIdArrayInstance.new(instance) }
      it 'inspects' do
        assert_equal("#[<NamedIdArrayInstance> \"foo\", \#{<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/1)> \"lamp\" => [3]}, #[<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/2)> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print named with id' do
      let(:subject) { NamedIdArrayInstance.new(instance) }
      it 'inspects' do
        assert_equal("#[<NamedIdArrayInstance>\n  \"foo\",\n  \#{<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/1)>\n    \"lamp\" => [3]\n  },\n  #[<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/2)>\n    \"q\",\n    \"r\"\n  ],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect named with id SortOfArray' do
      let(:subject) { NamedIdArrayInstance.new(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<NamedIdArrayInstance SortOfArray> \"foo\", \#{<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/1)> \"lamp\" => [3]}, #[<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/2)> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print named with id SortOfArray' do
      let(:subject) { NamedIdArrayInstance.new(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<NamedIdArrayInstance SortOfArray>\n  \"foo\",\n  \#{<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/1)>\n    \"lamp\" => [3]\n  },\n  #[<JSI (https://schemas.jsi.unth.net/test/base/named_array_schema#/items/2)>\n    \"q\",\n    \"r\"\n  ],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect with id' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/test/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(instance) }
      it 'inspects' do
        assert_equal("#[<JSI (https://schemas.jsi.unth.net/test/withid#)> \"foo\", \#{<JSI (https://schemas.jsi.unth.net/test/withid#/items/1)> \"lamp\" => [3]}, #[<JSI (https://schemas.jsi.unth.net/test/withid#/items/2)> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/test/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(instance) }
      it 'inspects' do
        assert_equal("#[<JSI (https://schemas.jsi.unth.net/test/withid#)>\n  \"foo\",\n  \#{<JSI (https://schemas.jsi.unth.net/test/withid#/items/1)> \"lamp\" => [3]},\n  #[<JSI (https://schemas.jsi.unth.net/test/withid#/items/2)> \"q\", \"r\"],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect with id SortOfArray' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/test/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI (https://schemas.jsi.unth.net/test/withid#) SortOfArray> \"foo\", \#{<JSI (https://schemas.jsi.unth.net/test/withid#/items/1)> \"lamp\" => [3]}, #[<JSI (https://schemas.jsi.unth.net/test/withid#/items/2)> \"q\", \"r\"], {\"four\"=>4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id SortOfArray' do
      let(:schema_content) { {'$id' => 'https://schemas.jsi.unth.net/test/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI (https://schemas.jsi.unth.net/test/withid#) SortOfArray>\n  \"foo\",\n  \#{<JSI (https://schemas.jsi.unth.net/test/withid#/items/1)> \"lamp\" => [3]},\n  #[<JSI (https://schemas.jsi.unth.net/test/withid#/items/2)> \"q\", \"r\"],\n  {\"four\"=>4}\n]\n", subject.pretty_inspect)
      end
    end
    describe '#inspect Node' do
      let(:subject) { schema.new_jsi(JSI::JSON::Node.new_doc(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI JSI::JSON::ArrayNode fragment=\"#\"> \"foo\", \#{<JSI JSI::JSON::HashNode fragment=\"#/1\"> \"lamp\" => #[<JSI::JSON::ArrayNode fragment=\"#/1/lamp\"> 3]}, #[<JSI JSI::JSON::ArrayNode fragment=\"#/2\"> \"q\", \"r\"], \#{<JSI::JSON::HashNode fragment=\"#/3\"> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print Node' do
      let(:subject) { schema.new_jsi(JSI::JSON::Node.new_doc(instance)) }
      it 'pretty_prints' do
        assert_equal("#[<JSI JSI::JSON::ArrayNode fragment=\"#\">\n  \"foo\",\n  \#{<JSI JSI::JSON::HashNode fragment=\"#/1\">\n    \"lamp\" => #[<JSI::JSON::ArrayNode fragment=\"#/1/lamp\"> 3]\n  },\n  #[<JSI JSI::JSON::ArrayNode fragment=\"#/2\"> \"q\", \"r\"],\n  \#{<JSI::JSON::HashNode fragment=\"#/3\"> \"four\" => 4}\n]\n", subject.pretty_inspect)
      end
    end
  end
  # these methods just delegate to Array so not going to test excessively
  describe 'index only methods' do
    it('#each_index') { assert_equal([0, 1, 2, 3], subject.each_index.to_a) }
    it('#empty?')    { assert_equal(false, subject.empty?) }
    it('#length')   { assert_equal(4, subject.length) }
    it('#size')    { assert_equal(4, subject.size) }
  end
  describe 'index + element methods' do
    it('#|')  { assert_equal(['foo', subject[1], subject[2], subject[3], 0], subject | [0]) }
    it('#&')   { assert_equal(['foo'], subject & ['foo']) }
    it('#*')    { assert_equal(subject.to_a, subject * 1) }
    it('#+')     { assert_equal(subject.to_a, subject + []) }
    it('#-')      { assert_equal([subject[1], subject[2], subject[3]], subject - ['foo']) }
    it('#<=>')     { assert_equal(1, subject <=> []) }
    it('#<=>')      { assert_equal(-1, [] <=> subject) }
    require 'abbrev'
    it('#abbrev')    { assert_equal({'a' => 'a'}, schema.new_jsi(['a']).abbrev) }
    it('#assoc')      { assert_equal(['q', 'r'], subject.assoc('q')) }
    it('#at')          { assert_equal('foo', subject.at(0)) }
    it('#bsearch')      { assert_equal(nil, subject.bsearch { false }) }
    it('#bsearch_index') { assert_equal(nil, subject.bsearch_index { false }) } if [].respond_to?(:bsearch_index)
    it('#combination')  { assert_equal([['foo'], [subject[1]], [subject[2]], [subject[3]]], subject.combination(1).to_a) }
    it('#count')       { assert_equal(1, subject.count('foo')) }
    it('#cycle')      { assert_equal(subject.to_a, subject.cycle(1).to_a) }
    it('#dig')       { assert_equal(3, subject.dig(1, 'lamp', 0)) } if [].respond_to?(:dig)
    it('#drop')      { assert_equal([subject[2], subject[3]], subject.drop(2)) }
    it('#drop_while') { assert_equal([subject[1], subject[2], subject[3]], subject.drop_while { |e| e == 'foo' }) }
    it('#fetch')     { assert_equal('foo', subject.fetch(0)) }
    it('#find_index') { assert_equal(0, subject.find_index { true }) }
    it('#first')     { assert_equal('foo', subject.first) }
    it('#include?') { assert_equal(true, subject.include?('foo')) }
    it('#index')   { assert_equal(0, subject.index('foo')) }
    it('#join')     { assert_equal('a b', schema.new_jsi(['a', 'b']).join(' ')) }
    it('#last')      { assert_equal(subject[3], subject.last) }
    it('#pack')       { assert_equal(' ', schema.new_jsi([32]).pack('c')) }
    it('#permutation') { assert_equal([['foo'], [subject[1]], [subject[2]], [subject[3]]], subject.permutation(1).to_a) }
    it('#product')    { assert_equal([], subject.product([])) }
    # due to differences in implementation between #assoc and #rassoc, the reason for which
    # I cannot begin to fathom, assoc works but rassoc does not because rassoc has different
    # type checking than assoc for the array(like) array elements.
    # compare:
    # assoc:  https://github.com/ruby/ruby/blob/v2_5_0/array.c#L3780-L3813
    # rassoc: https://github.com/ruby/ruby/blob/v2_5_0/array.c#L3815-L3847
    # for this reason, rassoc is NOT defined on Arraylike and we call #jsi_instance to use it.
    it('#rassoc')              { assert_equal(['q', 'r'], subject.jsi_instance.rassoc('r')) }
    it('#repeated_combination') { assert_equal([[]], subject.repeated_combination(0).to_a) }
    it('#repeated_permutation') { assert_equal([[]], subject.repeated_permutation(0).to_a) }
    it('#reverse')             { assert_equal([subject[3], subject[2], subject[1], 'foo'], subject.reverse) }
    it('#reverse_each')       { assert_equal([subject[3], subject[2], subject[1], 'foo'], subject.reverse_each.to_a) }
    it('#rindex')            { assert_equal(0, subject.rindex('foo')) }
    it('#rotate')           { assert_equal([subject[1], subject[2], subject[3], 'foo'], subject.rotate) }
    it('#sample')          { assert_equal('a', schema.new_jsi(['a']).sample) }
    it('#shelljoin')      { assert_equal('a', schema.new_jsi(['a']).shelljoin) } if [].respond_to?(:shelljoin)
    it('#shuffle')       { assert_equal(4, subject.shuffle.size) }
    it('#slice')        { assert_equal(['foo'], subject.slice(0, 1)) }
    it('#sort')        { assert_equal(['a'], schema.new_jsi(['a']).sort) }
    it('#take')       { assert_equal(['foo'], subject.take(1)) }
    it('#take_while') { assert_equal([], subject.take_while { false }) }
    it('#transpose') { assert_equal([], schema.new_jsi([]).transpose) }
    it('#uniq')     { assert_equal(subject.to_a, subject.uniq) }
    it('#values_at') { assert_equal(['foo'], subject.values_at(0)) }
    it('#zip')      { assert_equal([['foo', 'foo'], [subject[1], subject[1]], [subject[2], subject[2]], [subject[3], subject[3]]], subject.zip(subject)) }
  end
  describe 'with an instance that has to_ary but not other ary instance methods' do
    let(:instance) { SortOfArray.new(['foo', {'lamp' => SortOfArray.new([3])}, SortOfArray.new(['q', 'r'])]) }
    describe 'delegating instance methods to #to_ary' do
      it('#each_index') { assert_equal([0, 1, 2], subject.each_index.to_a) }
      it('#size')      { assert_equal(3, subject.size) }
      it('#count')    { assert_equal(1, subject.count('foo')) }
      it('#slice')   { assert_equal(['foo'], subject.slice(0, 1)) }
      it('#[]')     { assert_equal(SortOfArray.new(['q', 'r']), subject[2].jsi_instance) }
      it('#as_json') { assert_equal(['foo', {'lamp' => [3]}, ['q', 'r']], subject.as_json) }
    end
  end
  describe 'modified copy methods' do
    it('#reject') { assert_equal(schema.new_jsi(['foo']), subject.reject { |e| e != 'foo' }) }
    it('#reject block var') do
      subj_a = subject.to_a
      subject.reject { |e| assert_equal(e, subj_a.shift) }
    end
    it('#select') { assert_equal(schema.new_jsi(['foo']), subject.select { |e| e == 'foo' }) }
    it('#select block var') do
      subj_a = subject.to_a
      subject.select { |e| assert_equal(e, subj_a.shift) }
    end
    it('#compact') { assert_equal(subject, subject.compact) }
    describe 'at a depth' do
      it('#select') do
        expected = schema.new_jsi(['foo', {'lamp' => [3]}, ['r'], {'four' => 4}])[2]
        actual = subject[2].select { |e| e == 'r' }
        assert_equal(expected, actual)
      end
    end
  end
  JSI::Arraylike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!subject.respond_to?(destructive_method_name))
    end
  end
end
