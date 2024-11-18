# frozen_string_literal: true

module JSI
  dialect = Schema::Draft202012::DIALECT

  path = SCHEMAS_PATH.join('json-schema.org/draft/2020-12')
  metaschema_document = JSON.parse(path.join('schema.json').read, freeze: true)
  vocabulary_schema_documents = metaschema_document['allOf'].map do |schema|
    JSON.parse(path.join(schema['$ref'] + '.json').read, freeze: true)
  end

  jsi_schema_registry = SchemaRegistry.new
  bootstrap_schema_registry = SchemaRegistry.new
  bootstrap_metaschema = dialect.bootstrap_schema(metaschema_document, jsi_schema_registry: bootstrap_schema_registry)
  bootstrap_schema_registry.register(bootstrap_metaschema)
  vocabulary_schema_documents.each do |vocabulary_schema_document|
    bootstrap_vocabulary_schema = dialect.bootstrap_schema(vocabulary_schema_document, jsi_schema_registry: bootstrap_schema_registry)
    bootstrap_schema_registry.register(bootstrap_vocabulary_schema)
  end

  module JSONSchemaDraft202012
  end
end
