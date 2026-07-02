require_relative('test_helper')

describe("Base::Conf") do
  let(:metaschema) { JSI::JSONSchemaDraft07 }
  let(:schema) { JSI.new_schema(schema_content, default_metaschema: metaschema) }
  let(:schema_content) { {} }

  describe("Base::Conf / new_jsi") do
    it("returns a Base::Conf; it instantiates") do
      assert_instance_of(JSI::Base::Conf, schema.new_jsi)
      assert_is_a(JSI::Base, schema.new_jsi[{}])
    end
  end
end

$test_report_file_loaded[__FILE__]
