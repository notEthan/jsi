# frozen_string_literal: true

module JSI
  dialect = Schema::Draft202012::DIALECT

  path = SCHEMAS_PATH.join('json-schema.org/draft/2020-12')
  metaschema_document = JSON.parse(path.join('schema.json').read, freeze: true)
  vocabulary_schema_documents = metaschema_document['allOf'].map do |schema|
    JSON.parse(path.join(schema['$ref'] + '.json').read, freeze: true)
  end

  module JSONSchemaDraft202012
  end
end
