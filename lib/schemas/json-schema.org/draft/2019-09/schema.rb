module JSI
  draft201909path = RESOURCES_PATH.join('json-schema.org/draft/2019-09')
  draft201909content = ::JSON.parse(draft201909path.join('schema').read)
  schema_documents = draft201909content['allOf'].map do |schema|
    ::JSON.parse(draft201909path.join(schema['$ref']).read)
  end

  draft201909schema = MetaschemaNode.new(draft201909content, schema_documents: [draft201909content] + schema_documents)
  JSONSchemaOrgDraft201909 = draft201909schema.jsi_schema_module
end
