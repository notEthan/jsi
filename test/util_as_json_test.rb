require_relative 'test_helper'

class HashAsJson < Hash
  def as_json
    {'from' => 'HashAsJson#as_json'}
  end
end

class HashAsToJson < Hash
  def as_json
    {'from' => 'HashAsToJson#as_json'}
  end

  def to_json
    JSON.generate({'from' => 'HashAsToJson#to_json'})
  end
end

class OptJson
  def as_json(opt = nil)
    JSI::Util.as_json(opt)
  end
end

describe JSI::Util do
  describe('as_json, to_json') do
    before do
      # sanity check, ensure Util.as_json's to_hash/to_ary logic is tested, not overridden by as_json.
      # if any dependency of JSI defines these, need to reconsider assumptions with Hash/Array as_json.
      # if a test dependency defines these, reconfigure tests to avoid that.
      if Hash.method_defined?(:as_json) && ENV['JSI_TEST_EXTDEP']
        skip("external dependency defines Hash#as_json")
      end
    end

    it 'expresses as json' do
      assert_equal({}, JSI::Util.as_json({}))
      assert_equal([], JSI::Util.as_json([]))
      assert_equal(%q({}), JSI::Util.to_json({}))
      assert_equal(%q([]), JSI::Util.to_json([]))

      # symbols to string
      assert_equal(['a'], JSI::Util.as_json([:a]))
      assert_equal({'a' => 'b'}, JSI::Util.as_json({:a => :b}))
      assert_equal(%q(["a"]), JSI::Util.to_json([:a]))
      assert_equal(%q({"a":"b"}), JSI::Util.to_json({:a => :b}))

      # set
      assert_equal(['a'], JSI::Util.as_json(Set.new(['a'])))
      assert_equal(%q(["a"]), JSI::Util.to_json(Set.new(['a'])))

      # responds to #to_hash / #to_ary; no #as_json; does not use #to_json from JSON gem
      assert_equal({'a' => 'b'}, JSI::Util.as_json(SortOfHash.new({'a' => 'b'})))
      assert_equal(['a'], JSI::Util.as_json(SortOfArray.new(['a'])))
      assert_equal(%q({"a":"b"}), JSI::Util.to_json(SortOfHash.new({'a' => 'b'})))
      assert_equal(%q(["a"]), JSI::Util.to_json(SortOfArray.new(['a'])))
      assert_raises(TypeError) { JSI::Util.as_json(SortOfHash.new(0)) }
      assert_raises(TypeError) { JSI::Util.as_json(SortOfArray.new(0)) }
      assert_raises(TypeError) { JSI::Util.to_json(SortOfHash.new(0)) }
      assert_raises(TypeError) { JSI::Util.to_json(SortOfArray.new(0)) }

      # responds to #as_json; does not use #to_json from JSON gem
      o = HashAsJson.new
      assert_match(/\AJSON::\w+::Generator::GeneratorMethods::Hash\z/, o.method(:to_json).owner.name)
      assert_equal({'from' => 'HashAsJson#as_json'}, JSI::Util.as_json(o))
      assert_equal(%q({"from":"HashAsJson#as_json"}), JSI::Util.to_json(o))

      # responds to #as_json; uses #to_json (not from JSON gem)
      o = HashAsToJson.new
      assert_equal({'from' => 'HashAsToJson#as_json'}, JSI::Util.as_json(o))
      assert_equal(%q({"from":"HashAsToJson#to_json"}), JSI::Util.to_json(o))

      # symbol keys to string
      assert_equal({'a' => 'b'}, JSI::Util.as_json({a: 'b'}))
      assert_equal(%q({"a":"b"}), JSI::Util.to_json({a: 'b'}))
      # to_str key
      assert_equal({'a' => 'b'}, JSI::Util.as_json({SortOfString.new('a') => 'b'}))
      assert_equal(%q({"a":"b"}), JSI::Util.to_json({SortOfString.new('a') => 'b'}))
      # non string/symbol key
      err = assert_raises(TypeError) { JSI::Util.as_json({nil => 0}) }
      assert_equal('json object (hash) cannot be keyed with: nil', err.message)
      assert_raises(TypeError) { JSI::Util.to_json({nil => 0}) }

      # numbers
      assert_equal(2.0, JSI::Util.as_json(2.0))
      assert_raises(TypeError) { JSI::Util.as_json(1.0 / 0) }
      assert_raises(TypeError) { JSI::Util.as_json(0.0 / 0) }
      assert_raises(TypeError) { JSI::Util.to_json(1.0 / 0) }

      # schema
      schema = JSI::JSONSchemaDraft07.new_schema({'type' => 'array'})
      assert_equal({'type' => 'array'}, JSI::Util.as_json(schema))
      assert_equal(%q({"type":"array"}), JSI::Util.to_json(schema))

      # JSI
      assert_equal(['a'], JSI::Util.as_json(schema.new_jsi(['a'])))
      assert_equal(%q(["a"]), JSI::Util.to_json(schema.new_jsi(['a'])))

      # Addressable::URI, which responds to both #to_hash and #to_str
      assert_equal('tag:x', JSI::Util.as_json(Addressable::URI.parse('tag:x')))
      assert_equal(%q("tag:x"), JSI::Util.to_json(Addressable::URI.parse('tag:x')))

      # #as_json opt
      assert_equal({'a' => 0}, JSI::Util.as_json(OptJson.new, a: 0))
      assert_equal({'a' => 0}, JSI::SchemaSet[].new_jsi(OptJson.new, to_immutable: nil).as_json(a: 0))
      assert_equal(nil, JSI::Util.as_json(OptJson.new))
      assert_equal(nil, JSI::SchemaSet[].new_jsi(OptJson.new, to_immutable: nil).as_json)
      assert_equal(%q({"a":0}), JSI::Util.to_json(OptJson.new, a: 0))
      assert_equal(%q({"a":0}), JSI::SchemaSet[].new_jsi(OptJson.new, to_immutable: nil).to_json(a: 0))
      assert_equal("null", JSI::Util.to_json(OptJson.new))
      assert_equal("null", JSI::SchemaSet[].new_jsi(OptJson.new, to_immutable: nil).to_json)

      # not jsonifiable
      object = Object.new
      err = assert_raises(TypeError) { JSI::Util.as_json(object) }
      assert_equal("cannot express object as json: #{object.pretty_inspect.chomp}", err.message)
      assert_raises(TypeError) { JSI::Util.to_json(object) }
    end
  end
end

$test_report_file_loaded[__FILE__]
