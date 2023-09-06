require_relative '../test_helper'

require 'spreedly_openapi'
describe 'spreedly openapi' do
  it 'instantiates the spreedly openapi doc' do
    SpreedlyOpenAPI::Document.inspect
  end
end

$test_report_file_loaded[__FILE__]
