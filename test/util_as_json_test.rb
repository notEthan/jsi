require_relative 'test_helper'

class JSONifiable
  def initialize(object)
    @object = object
  end
  def as_json
    @object
  end
end

class OptJson
  def as_json(opt = nil)
    JSI::Util.as_json(opt)
  end
end

describe JSI::Util do
  describe 'as_json' do
    it 'expresses as json' do
      assert_equal({}, JSI::Util.as_json({}))
      assert_equal([], JSI::Util.as_json([]))

      # symbols to string
      assert_equal(['a'], JSI::Util.as_json([:a]))
      assert_equal({'a' => 'b'}, JSI::Util.as_json({:a => :b}))

      # set
      assert_equal(['a'], JSI::Util.as_json(Set.new(['a'])))

      # responds to #to_hash / #to_ary but naught else
      assert_equal({'a' => 'b'}, JSI::Util.as_json(SortOfHash.new({'a' => 'b'})))
      assert_equal(['a'], JSI::Util.as_json(SortOfArray.new(['a'])))
      assert_raises(TypeError) { JSI::Util.as_json(SortOfHash.new(0)) }
      assert_raises(TypeError) { JSI::Util.as_json(SortOfArray.new(0)) }

      # symbol keys to string
      assert_equal({'a' => 'b'}, JSI::Util.as_json({a: 'b'}))
      # non string/symbol key
      err = assert_raises(TypeError) { JSI::Util.as_json({nil => 0}) }
      assert_equal('json object (hash) cannot be keyed with: nil', err.message)

      # numbers
      assert_equal(2.0, JSI::Util.as_json(2.0))
      assert_raises(TypeError) { JSI::Util.as_json(1.0 / 0) }
      assert_raises(TypeError) { JSI::Util.as_json(0.0 / 0) }

      # schema
      schema = JSI::JSONSchemaDraft07.new_schema({'type' => 'array'})
      assert_equal({'type' => 'array'}, JSI::Util.as_json(schema))

      # JSI
      assert_equal(['a'], JSI::Util.as_json(schema.new_jsi(['a'])))

      # Addressable::URI, which responds to both #to_hash and #to_str
      assert_equal('tag:x', JSI::Util.as_json(Addressable::URI.parse('tag:x')))

      # #as_json
      assert_equal(['a'], JSI::Util.as_json(JSONifiable.new(['a'])))

      # #as_json opt
      assert_equal({'a' => 0}, JSI::Util.as_json(OptJson.new, a: 0))
      assert_equal({'a' => 0}, JSI::SchemaSet[].new_jsi(OptJson.new).as_json(a: 0))
      assert_equal(nil, JSI::Util.as_json(OptJson.new))
      assert_equal(nil, JSI::SchemaSet[].new_jsi(OptJson.new).as_json)

      # not jsonifiable
      object = Object.new
      err = assert_raises(TypeError) { JSI::Util.as_json(object) }
      assert_equal("cannot express object as json: #{object.pretty_inspect.chomp}", err.message)
    end
  end
end

$test_report_file_loaded[__FILE__]
