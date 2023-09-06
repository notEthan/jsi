require_relative 'test_helper'

class JSONifiable
  def initialize(object)
    @object = object
  end
  def as_json
    @object
  end
end

describe JSI::Util do
  describe 'as_json' do
    it 'expresses as json' do
      assert_equal({}, JSI::Util.as_json({}))
      assert_equal([], JSI::Util.as_json([]))

      # symbols to string
      assert_equal(['a'], JSI::Util.as_json([:a]))

      # set
      assert_equal(['a'], JSI::Util.as_json(Set.new(['a'])))

      # responds to #to_hash / #to_ary but naught else
      assert_equal({'a' => 'b'}, JSI::Util.as_json(SortOfHash.new({'a' => 'b'})))
      assert_equal(['a'], JSI::Util.as_json(SortOfArray.new(['a'])))

      # symbol keys to string
      assert_equal({'a' => 'b'}, JSI::Util.as_json({a: 'b'}))
      # non string/symbol key
      err = assert_raises(TypeError) { JSI::Util.as_json({nil => 0}) }
      assert_equal('json object (hash) cannot be keyed with: nil', err.message)

      # schema
      schema = JSI::JSONSchemaOrgDraft07.new_schema({'type' => 'array'})
      assert_equal({'type' => 'array'}, JSI::Util.as_json(schema))

      # JSI
      assert_equal(['a'], JSI::Util.as_json(schema.new_jsi(['a'])))

      # #as_json
      assert_equal(['a'], JSI::Util.as_json(JSONifiable.new(['a'])))

      # not jsonifiable
      object = Object.new
      err = assert_raises(TypeError) { JSI::Util.as_json(object) }
      assert_equal("cannot express object as json: #{object.pretty_inspect.chomp}", err.message)
    end
  end
end

$test_report_file_loaded[__FILE__]
