require_relative 'test_helper'

describe 'JSI::Base array' do
  module BaseArrayTest
    def self.test_ranges(test_context)
      size = 4
      n = 2
      classes = [
        ["negative beyond size", -1,  -> (m) { -size - m }],
        ["negative at size",     0,   -> (m) { -size }],
        ["negative within size", -1,  -> (m) { -m }],
        ["zero",                 0,   -> (m) { 0 }],
        (["nil",                 0,   -> (m) { nil }] if (nil..0 rescue false)), # compatibility: skip on ancient ruby versions without beginless/endless ranges
        ["positive within size", 1,   -> (m) { m }],
        ["positive at size",     0,   -> (m) { size }],
        ["positive beyond size", 1,   -> (m) { size + m }],
      ].compact

      mkit = -> (range, startclassname, endclassname, *descs) do
        range_s = ((" " * (range.begin || range.end ? 3 - (range.begin.to_s.size) : 0)) + range.inspect).ljust(9)
        indices = (0...size).to_a[range]
        desc = ["range #{range_s} → #{indices.inspect} : start #{startclassname}, end #{endclassname}", *descs].join(", ")
        test_context.it(desc) do
          expect = indices.nil? ? nil : indices.map { |i| subject[i] }
          assert_equal(expect, subject[range])
        end
      end

      classes.each do |startclassname, _, mkstart|
        classes.each do |endclassname, nvary, mkend|
          if nvary != 0 && startclassname == endclassname
            mkit.(mkstart[n]..mkend[n - nvary],  startclassname, endclassname, "inclusive", "start > end")
            mkit.(mkstart[n]...mkend[n - nvary], startclassname, endclassname, "exclusive", "start > end")
            mkit.(mkstart[n]..mkend[n],          startclassname, endclassname, "inclusive", "start = end")
            mkit.(mkstart[n]...mkend[n],         startclassname, endclassname, "exclusive", "start = end")
            mkit.(mkstart[n]..mkend[n + nvary],  startclassname, endclassname, "inclusive", "start < end")
            mkit.(mkstart[n]...mkend[n + nvary], startclassname, endclassname, "exclusive", "start < end")
          else
            mkit.(mkstart[n]..mkend[n],          startclassname, endclassname, "inclusive")
            mkit.(mkstart[n]...mkend[n],         startclassname, endclassname, "exclusive")
          end
        end
      end
    end
  end

  let(:default_instance) { ['foo', {'lamp' => [3]}, ['q', 'r'], {'four' => 4}] }
  let(:instance) { default_instance }
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
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: JSI::JSONSchemaDraft07) }
  let(:subject_opt) { {} }
  let(:subject) { schema.new_jsi(instance, **subject_opt) }

  describe '#[]' do
    describe 'negative index in range' do
      it 'returns the item before the end' do
        assert_equal(subject[0], subject[-4])
        assert_equal(subject[3], subject[-1])
      end
    end

    describe 'negative index out of range' do
      it 'returns nil' do
        assert_nil(subject[-5])
      end
    end

    describe 'Range' do
      BaseArrayTest.test_ranges(self)
    end

    describe 'arbitrary object' do
      it 'raises' do
        err = assert_raises(TypeError) { subject[{"valid" => 0}] }
        assert_equal(-"expected `token` param to be an Integer or Range\ntoken: #{{"valid" => 0}.inspect}", err.message)
      end
    end
  end

  describe("#[] with a default that is a simple type") do
    let(:schema_content) do
      {
        'type' => 'array',
        'items' => {'default' => 'foo'},
      }
    end

    schema_instance_child_use_default_default_true

    describe 'default value' do
      let(:instance) { [1] }
      it 'returns the default value' do
        assert_equal('foo', subject[2])
        assert_nil(subject[2, use_default: false])
      end
    end
    describe("nondefault value (simple type)") do
      let(:instance) { ['who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[0])
        assert_equal('who', subject[0, use_default: false])
      end
    end
    describe("nondefault value (complex type)") do
      let(:instance) { [[2]] }
      it 'returns the nondefault value' do
        assert_schemas([schema.items], subject[0])
        assert_equal([2], subject[0].jsi_instance)
      end
    end

    describe 'negative index out of range' do
      it("returns nil, does not try to insert simple default") do
        assert_nil(subject[-5])
      end
    end

    describe 'Range' do
      # it does not try to insert simple defaults, so behavior is the same as tests without a default value.
      BaseArrayTest.test_ranges(self)
    end

    describe 'arbitrary object' do
      it("raises, does not try to insert simple default") do
        assert_raises(TypeError) { subject[Object.new] }
      end
    end
  end
  describe("#[] with a default that is a complex type") do
    let(:schema_content) do
      {
        'type' => 'array',
        'items' => {'default' => {'foo' => 2}},
      }
    end

    schema_instance_child_use_default_default_true

    describe 'default value' do
      let(:instance) { [{'bar' => 3}] }
      it 'returns the default value' do
        assert_schemas([schema.items], subject[1])
        assert_nil(subject[1, use_default: false])
        assert_equal({'foo' => 2}, subject[1].jsi_instance)
      end
    end
    describe("nondefault value (simple type)") do
      let(:instance) { [true, 'who'] }
      it 'returns the nondefault value' do
        assert_equal('who', subject[1])
        assert_equal('who', subject[1, use_default: false])
      end
    end
    describe("nondefault value (complex type)") do
      let(:instance) { [true, [2]] }
      it 'returns the nondefault value' do
        assert_schemas([schema.items], subject[1])
        assert_equal([2], subject[1].jsi_instance)
      end
    end

    describe 'negative index out of range' do
      it 'returns nil, does not try to insert complex default' do
        assert_nil(subject[-5])
      end
    end

    describe 'Range' do
      # it does not try to insert complex defaults, so behavior is the same as tests without a default value.
      BaseArrayTest.test_ranges(self)
    end

    describe 'arbitrary object' do
      it 'raises, does not try to insert complex default' do
        assert_raises(TypeError) { subject[Object.new] }
      end
    end
  end
  describe 'arraylike []=' do
    let(:subject_opt) { {mutable: true} }

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

    describe 'negative index' do
      it 'assigns the index from the end' do
        subject[-2] = 'foo'
        assert_equal(schema.new_jsi(["foo", {"lamp" => [3]}, "foo", {"four" => 4}]), subject)
        subject[-2] = ['foo']
        assert_equal(schema.new_jsi(["foo", {"lamp" => [3]}, ["foo"], {"four" => 4}]), subject)
      end

      it 'raises given index pointing before the start' do
        assert_raises(IndexError) { subject[-5] = 'foo' }
        assert_raises(IndexError) { subject[-5] = ['foo'] }
      end
    end

    describe 'Range' do
      it 'assigns a range within the current token range' do
        subject[0...2] = ['a']
        assert_equal(schema.new_jsi(["a", ["q", "r"], {"four" => 4}]), subject)
      end

      it 'assigns a range expanding the current token range' do
        # note that 5 is off the end, and 3..5 is smaller than the actual array. this is fine.
        subject[3..5] = ['a', 'b', 'c', 'd']
        assert_equal(schema.new_jsi(["foo", {"lamp" => [3]}, ["q", "r"], "a", "b", "c", "d"]), subject)
      end

      it 'assigns a range off the end' do
        subject[6...99] = ['a']
        assert_equal(schema.new_jsi(["foo", {"lamp" => [3]}, ["q", "r"], {"four" => 4}, nil, nil, "a"]), subject)
      end
    end

    describe 'when the instance is not arraylike' do
      let(:instance) { nil }
      it 'errors' do
        err = assert_raises(JSI::Base::SimpleNodeChildError) { subject[2] = 0 }
        assert_equal(%Q(cannot access a child of this JSI node because this node is not complex\nusing token: 2\ninstance: nil), err.message)
      end
    end
  end

  describe("pretty") do
    describe '#inspect, #to_s' do
      it 'inspects' do
        assert_equal("#[<JSI*1> \"foo\", \#{<JSI*1> \"lamp\" => #[<JSI*0> 3]}, #[<JSI*1> \"q\", \"r\"], \#{<JSI*0> \"four\" => 4}]", subject.inspect)
        assert_equal(subject.inspect, subject.to_s)
      end
    end
    describe '#pretty_print' do
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI*1>
            "foo",
            \#{<JSI*1> "lamp" => #[<JSI*0> 3]},
            #[<JSI*1> "q", "r"],
            \#{<JSI*0> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end

      describe 'with a long module name' do
        ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines = JSI::JSONSchemaDraft07.new_schema_module({"$id": "jsi:2be3"})
        it 'does not break empty array' do
          subject = ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines.new_jsi([])
          pp = %Q(\#[<JSI (ArraySchemaWithAModuleNameLongEnoughForPrettyPrintToBreakOverMultipleLines)>]\n)
          assert_equal(pp, subject.pretty_inspect)
        end
      end
    end
    describe '#inspect SortOfArray' do
      let(:instance) { SortOfArray.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'inspects' do
        assert_equal("#[<JSI*1 SortOfArray> \"foo\", \#{<JSI*1> \"lamp\" => #[<JSI*0> 3]}, #[<JSI*1> \"q\", \"r\"], \#{<JSI*0> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print SortOfArray' do
      let(:instance) { SortOfArray.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI*1 SortOfArray>
            "foo",
            \#{<JSI*1> "lamp" => #[<JSI*0> 3]},
            #[<JSI*1> "q", "r"],
            \#{<JSI*0> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      it 'inspects' do
        assert_equal("#[<JSI (http://jsi/base_array/withid)> \"foo\", \#{<JSI (http://jsi/base_array/withid#/items/1)> \"lamp\" => #[<JSI*0> 3]}, #[<JSI (http://jsi/base_array/withid#/items/2)> \"q\", \"r\"], \#{<JSI*0> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI (http://jsi/base_array/withid)>
            "foo",
            \#{<JSI (http://jsi/base_array/withid#/items/1)> "lamp" => #[<JSI*0> 3]},
            #[<JSI (http://jsi/base_array/withid#/items/2)> "q", "r"],
            \#{<JSI*0> "four" => 4}
          ]
          PP
        assert_equal(pp, subject.pretty_inspect)
      end
    end
    describe '#inspect with id SortOfArray' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      let(:instance) { SortOfArray.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'inspects' do
        assert_equal("#[<JSI (http://jsi/base_array/withid) SortOfArray> \"foo\", \#{<JSI (http://jsi/base_array/withid#/items/1)> \"lamp\" => #[<JSI*0> 3]}, #[<JSI (http://jsi/base_array/withid#/items/2)> \"q\", \"r\"], \#{<JSI*0> \"four\" => 4}]", subject.inspect)
      end
    end
    describe '#pretty_print with id SortOfArray' do
      let(:schema_content) { {'$id' => 'http://jsi/base_array/withid', 'items' => [{}, {}, {}]} }
      let(:instance) { SortOfArray.new(default_instance) }
      let(:subject_opt) { {to_immutable: nil} }
      it 'pretty prints' do
        pp = <<~PP
          #[<JSI (http://jsi/base_array/withid) SortOfArray>
            "foo",
            \#{<JSI (http://jsi/base_array/withid#/items/1)> "lamp" => #[<JSI*0> 3]},
            #[<JSI (http://jsi/base_array/withid#/items/2)> "q", "r"],
            \#{<JSI*0> "four" => 4}
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
    if ([32].pack('c', buffer: +'') rescue false) # compat: no #pack keywords on ruby < 2.4, truffleruby
      it('#pack kw')    { assert_equal(' ', schema.new_jsi([32]).pack('c', buffer: +'')) }
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
    let(:subject_opt) { {to_immutable: nil} }
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
        assert_equal(schema.new_jsi(['foo', {'lamp' => SortOfArray.new([3])}, []], **subject_opt), modified_root)
      end
    end
  end
  describe 'modified copy methods' do
    it('#reject') { assert_equal(schema.new_jsi(['foo']), subject.reject { |e| e != 'foo' }) }
    it('#reject block param is Base#[]') do
      i = 0
      subject.reject { |e| assert_equal(e, subject[i]); i += 1 }
    end
    it('#select') { assert_equal(schema.new_jsi(['foo']), subject.select { |e| e == 'foo' }) }
    it('#select block param is Base#[]') do
      i = 0
      subject.select { |e| assert_equal(e, subject[i]); i += 1 }
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

$test_report_file_loaded[__FILE__]
