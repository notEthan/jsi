require_relative 'test_helper'

describe 'JSI::Base array' do
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
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaOrgDraft07) }
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
        assert_nil(subject[2, use_default: false])
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { ['who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[0])
        assert_equal('who', subject[0, use_default: false])
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { [[2]] }
      it 'returns the nondefault value' do
        assert_schemas([schema.items], subject[0])
        assert_equal([2], subject[0].jsi_instance)
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
        assert_schemas([schema.items], subject[1])
        assert_nil(subject[1, use_default: false])
        assert_equal({'foo' => 2}, subject[1].jsi_instance)
      end
    end
    describe 'nondefault value (basic type)' do
      let(:instance) { [true, 'who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[1])
        assert_equal('who', subject[1, use_default: false])
      end
    end
    describe 'nondefault value (nonbasic type)' do
      let(:instance) { [true, [2]] }
      it 'returns the nondefault value' do
        assert_schemas([schema.items], subject[1])
        assert_equal([2], subject[1].jsi_instance)
      end
    end
  end
  describe 'arraylike []=' do
    it 'sets an index' do
      orig_2 = subject[2]

      subject[2] = {'y' => 'z'}

      assert_equal({'y' => 'z'}, subject[2].jsi_instance)
      assert_schemas([schema.items[2]], orig_2)
      assert_schemas([schema.items[2]], subject[2])
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
        err = assert_raises(JSI::Base::CannotSubscriptError) { subject[2] = 0 }
        assert_equal("cannot assign subscript (using token: 2) to instance: nil", err.message)
      end
    end
    describe '#inspect, #to_s' do
      it 'inspects' do
        assert_equal("#[<JSI> \"foo\", \#{<JSI> \"lamp\" => #[<JSI> 3]}, #[<JSI> \"q\", \"r\"], \#{<JSI> \"four\" => 4}]", subject.inspect)
        assert_equal(subject.inspect, subject.to_s)
      end
    end
    describe '#pretty_print' do
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI>
            "foo",
            \#{<JSI> "lamp" => #[<JSI> 3]},
            #[<JSI> "q", "r"],
            \#{<JSI> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end

      describe 'with a long module name' do
        ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines = JSI::JSONSchemaOrgDraft07.new_schema_module({"$id": "jsi:2be3"})
        it 'does not break empty hash' do
          subject = ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines.new_jsi([])
          pp = %Q(\#[<JSI (ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines)>]\n)
          assert_equal(pp, subject.pretty_inspect)
        end
      end
    end
    describe '#inspect SortOfArray' do
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI SortOfArray> \"foo\", \#{<JSI> \"lamp\" => #[<JSI> 3]}, #[<JSI> \"q\", \"r\"], \#{<JSI> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print SortOfArray' do
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI SortOfArray>
            "foo",
            \#{<JSI> "lamp" => #[<JSI> 3]},
            #[<JSI> "q", "r"],
            \#{<JSI> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      it 'inspects' do
        assert_equal("#[<JSI (http://jsi/base_array/withid)> \"foo\", \#{<JSI (http://jsi/base_array/withid#/items/1)> \"lamp\" => #[<JSI> 3]}, #[<JSI (http://jsi/base_array/withid#/items/2)> \"q\", \"r\"], \#{<JSI> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI (http://jsi/base_array/withid)>
            "foo",
            \#{<JSI (http://jsi/base_array/withid#/items/1)> "lamp" => #[<JSI> 3]},
            #[<JSI (http://jsi/base_array/withid#/items/2)> "q", "r"],
            \#{<JSI> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id SortOfArray' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'inspects' do
        assert_equal("#[<JSI (http://jsi/base_array/withid) SortOfArray> \"foo\", \#{<JSI (http://jsi/base_array/withid#/items/1)> \"lamp\" => #[<JSI> 3]}, #[<JSI (http://jsi/base_array/withid#/items/2)> \"q\", \"r\"], \#{<JSI> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id SortOfArray' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      let(:subject) { schema.new_jsi(SortOfArray.new(instance)) }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI (http://jsi/base_array/withid) SortOfArray>
            "foo",
            \#{<JSI (http://jsi/base_array/withid#/items/1)> "lamp" => #[<JSI> 3]},
            #[<JSI (http://jsi/base_array/withid#/items/2)> "q", "r"],
            \#{<JSI> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
  end
  describe 'each' do
    it 'yields each element' do
      expect_modules = [String, schema.items[1].jsi_schema_module, schema.items[2].jsi_schema_module, JSI::Base::HashNode]
      subject.each { |e| assert_is_a(expect_modules.shift, e) }
    end
    it 'yields each element as_jsi' do
      expect_schemas = [[schema.items[0]], [schema.items[1]], [schema.items[2]], []]
      subject.each(as_jsi: true) { |e| assert_schemas(expect_schemas.shift, e) }
    end
  end
  describe 'to_ary' do
    it 'includes each element' do
      expect_modules = [String, schema.items[1].jsi_schema_module, schema.items[2].jsi_schema_module, JSI::Base::HashNode]
      subject.to_ary.each { |e| assert_is_a(expect_modules.shift, e) }
    end
    it 'includes each element as_jsi' do
      expect_schemas = [[schema.items[0]], [schema.items[1]], [schema.items[2]], []]
      subject.to_ary(as_jsi: true).each { |e| assert_schemas(expect_schemas.shift, e) }
    end
  end

  describe 'to_a' do
    it 'is an array' do
      expect_ary = [subject[0], subject[1], subject[2], subject[3]]
      assert_equal(expect_ary, subject.to_a)
    end

    it 'is an array of JSIs' do
      expect_ary = instance.each_index.map { |i| subject.jsi_descendent_node([i]) }
      assert_equal(expect_ary, subject.to_a(as_jsi: true))
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
    it('#assoc')      { assert_equal(subject[2], subject.assoc('q')) }
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
    if ([32].pack('c', buffer: '') rescue false) # compat: no #pack keywords on ruby < 2.4, truffleruby
      it('#pack kw')    { assert_equal(' ', schema.new_jsi([32]).pack('c', buffer: '')) }
    end
    it('#permutation') { assert_equal([['foo'], [subject[1]], [subject[2]], [subject[3]]], subject.permutation(1).to_a) }
    it('#product')    { assert_equal([], subject.product([])) }
    it('#rassoc')              { assert_equal(subject[2], subject.rassoc('r')) }
    it('#repeated_combination') { assert_equal([[]], subject.repeated_combination(0).to_a) }
    it('#repeated_permutation') { assert_equal([[]], subject.repeated_permutation(0).to_a) }
    it('#reverse')             { assert_equal([subject[3], subject[2], subject[1], 'foo'], subject.reverse) }
    it('#reverse_each')       { assert_equal([subject[3], subject[2], subject[1], 'foo'], subject.reverse_each.to_a) }
    it('#rindex')            { assert_equal(0, subject.rindex('foo')) }
    it('#rotate')           { assert_equal([subject[1], subject[2], subject[3], 'foo'], subject.rotate) }
    it('#sample')          { assert_equal('a', schema.new_jsi(['a']).sample) }
    it('#sample kw')       { assert_equal('a', schema.new_jsi(['a']).sample(random: Random.new(1))) }
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

    describe 'modified copy' do
      it 'modifies a copy' do
        modified_root = subject[2].select { false }.jsi_root_node
        # modified_root instance ceases to be SortOfArray because SortOfArray has no #[]= method
        # modified_root[2] ceases to be SortOfArray because SortOfArray has no #select method
        assert_equal(schema.new_jsi(['foo', {'lamp' => SortOfArray.new([3])}, []]), modified_root)
      end
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
    describe '#select' do
      it 'passes as_jsi' do
        result = subject.select(as_jsi: true) do |e|
          e.jsi_schemas.empty?
        end
        assert_equal(schema.new_jsi([{"four" => 4}]), result)
      end
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
  JSI::Util::Arraylike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!subject.respond_to?(destructive_method_name))
    end
  end
end
