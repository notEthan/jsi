# frozen_string_literal: true

require_relative 'test_helper'

# tests of private APIs. although private methods are usually tested indirectly, called by public APIs they
# exist to support, some code paths for development or debugging are not.

module TestSchemaImplModule
end

describe JSI::MetaschemaNode::BootstrapSchema do
  let(:bootstrap_schema_class) { JSI::SchemaClasses.bootstrap_schema_class([TestSchemaImplModule]) }
  let(:document) do
    JSI::DEFAULT_CONTENT_TO_IMMUTABLE[{
      "properties" => {
        "properties" => {"additionalProperties" => {"$ref" => "#"}},
        "additionalProperties" => {"$ref" => "#"},
        "$ref" => {}
      }
    }]
  end

  it 'is not directly instantiable' do
    assert_raises(JSI::Bug) { JSI::MetaschemaNode::BootstrapSchema.new({}) }
  end

  it 'is pretty' do
    schema = bootstrap_schema_class.new(document)

    inspect = %q(#<JSI::MetaschemaNode::BootstrapSchema (TestSchemaImplModule) # {"properties"=>{"properties"=>{"additionalProperties"=>{"$ref"=>"#"}}, "additionalProperties"=>{"$ref"=>"#"}, "$ref"=>{}}}>)
    assert_equal(inspect, schema.inspect)

    assert_equal(schema.inspect, schema.to_s)

    pp = <<~PP
      #<JSI::MetaschemaNode::BootstrapSchema (TestSchemaImplModule) #
        {"properties"=>
          {"properties"=>{"additionalProperties"=>{"$ref"=>"#"}},
           "additionalProperties"=>{"$ref"=>"#"},
           "$ref"=>{}}}
      >
      PP
    assert_equal(pp, schema.pretty_inspect)
  end

  it 'has a named class' do
    assert_equal('JSI::MetaschemaNode::BootstrapSchema', JSI::MetaschemaNode::BootstrapSchema.inspect)
    assert_equal('JSI::MetaschemaNode::BootstrapSchema (TestSchemaImplModule)', bootstrap_schema_class.inspect)
  end
end

$test_report_file_loaded[__FILE__]
