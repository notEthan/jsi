require_relative 'test_helper'

describe 'JSI Schema inplace application' do
  let(:schema) { metaschema.new_schema(schema_content) }
  let(:subject) { schema.new_jsi(instance) }
end
