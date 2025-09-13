# frozen_string_literal: true

require_relative 'test_helper'

# tests of private APIs. although private methods are usually tested indirectly, called by public APIs they
# exist to support, some code paths for development or debugging are not.

describe(JSI::MetaSchemaNode::BootstrapSchema) do
  let(:dialect) { JSI::Schema::Dialect.new(id: 'tag:dialect:dqzk', vocabularies: []) }
  let(:document) do
    JSI::DEFAULT_CONTENT_TO_IMMUTABLE[{
      "properties" => {
        "properties" => {"additionalProperties" => {"$ref" => "#"}},
        "additionalProperties" => {"$ref" => "#"},
        "$ref" => {}
      }
    }]
  end

  it 'is pretty' do
    schema = dialect.bootstrap_schema(document)

    inspect = -%Q(#<JSI::MetaSchemaNode::BootstrapSchema (tag:dialect:dqzk) # #{document.inspect}>)
    assert_equal(inspect, schema.inspect)

    assert_equal(schema.inspect, schema.to_s)
    assert_match(%r(\A#<JSI::MetaSchemaNode::BootstrapSchema \(tag:dialect:dqzk\) #\n  .*\n>\Z)m, schema.pretty_inspect)
  end
end

$test_report_file_loaded[__FILE__]
