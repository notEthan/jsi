# frozen_string_literal: true

=begin
module JSI
  draft201909path = RESOURCES_PATH.join('json-schema.org/draft/2019-09')
  draft201909content = ::JSON.parse(draft201909path.join('schema').read)
  schema_documents = [draft201909content] + draft201909content['allOf'].map do |schema|
    ::JSON.parse(draft201909path.join(schema['$ref']).read)
  end

  schema_documents.each do |doc|
    JSI.schema_registry.register_document(doc['$id'], doc)
  end
  draft201909schema = MetaschemaNode.new(draft201909content,
    root_basic_schema: JSI::BasicSchema::Draft201909.new(JSI::JSON::Pointer[], draft201909content),
    schema_documents: schema_documents
  )
  draft201909schema.jsi_register_schema
  JSONSchemaOrgDraft201909 = draft201909schema.jsi_schema_module
end
=end

=begin
irb -Ilib -rjsi -r active_support -r active_support/core_ext/hash/deep_merge

draft201909path = JSI::RESOURCES_PATH.join('json-schema.org/draft/2019-09')
draft201909content = ::JSON.parse(draft201909path.join('schema').read)
schema_documents = [draft201909content] + draft201909content['allOf'].map do |schema|
  ::JSON.parse(draft201909path.join(schema['$ref']).read)
end

schema_documents.inject({}) { |o, sd| o.deep_merge(sd) }.to_yaml(line_width: -1).pbcopy
=end

require 'yaml'

module JSI
  schema_content = ::YAML.safe_load(RESOURCES_PATH.join('json-schema.org/draft/2019-09/schema-unified.yaml').read)

  JSONSchemaOrgDraft201909 = Metaschema.new(schema_content,
    jsi_metaschema_module: JSI::Schema::Draft201909,
#  ).jsi_schema_module
  ).tap(&:jsi_register_schema).jsi_schema_module
end
