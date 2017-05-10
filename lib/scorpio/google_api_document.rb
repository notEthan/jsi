require 'scorpio/schema_object_base'
require 'yaml'

module Scorpio
  module Google
    apidoc_schema_doc = YAML.load_file(File.join(File.dirname(__FILE__), '../../getRest.yml'))
    api_document_class = proc do |key|
      Scorpio.class_for_schema(apidoc_schema_doc['schemas'][key], apidoc_schema_doc)
    end

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::Google::ApiDocument.document['schemas'].select { |k,v| v['type'] == 'object' }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = api_document_class.call('#{k}')" }
    DirectoryList   = api_document_class.call('DirectoryList')
    JsonSchema      = api_document_class.call('JsonSchema')
    RestDescription = api_document_class.call('RestDescription')
    RestMethod      = api_document_class.call('RestMethod')
    RestResource    = api_document_class.call('RestResource')
  end
end
