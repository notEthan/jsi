# frozen_string_literal: true

module JSI
  path = SCHEMAS_PATH.join('json-schema.org/draft/2020-12')
  metaschema_document = Util.json_parse_freeze(path.join('schema.json').read)
  vocabulary_schema_documents = metaschema_document['allOf'].map do |schema|
    Util.json_parse_freeze(path.join(schema['$ref'] + '.json').read)
  end
  jsi_registry = Registry.new

  JSONSchemaDraft202012 = JSI.new_metaschema_node(metaschema_document,
    dialect: Schema::Draft202012::DIALECT,
    registry: jsi_registry,
    metaschema_root_ref: 'https://json-schema.org/draft/2020-12/schema',
    schema_documents: vocabulary_schema_documents,
  ).jsi_schema_module

  module JSONSchemaDraft202012
    def self.name_vocab_schemas(metaschema_module, namespace: metaschema_module)
      find_module = proc { |uri| metaschema_module.schema.jsi_registry.find(uri).with_dynamic_scope_from(metaschema_module).jsi_schema_module }
      namespace.const_set(:Core,       find_module["https://json-schema.org/draft/2020-12/meta/core"])
      namespace.const_set(:Applicator,  find_module["https://json-schema.org/draft/2020-12/meta/applicator"])
      namespace.const_set(:Unevaluated,  find_module["https://json-schema.org/draft/2020-12/meta/unevaluated"])
      namespace.const_set(:Validation,    find_module["https://json-schema.org/draft/2020-12/meta/validation"])
      namespace.const_set(:MetaData,       find_module["https://json-schema.org/draft/2020-12/meta/meta-data"])
      namespace.const_set(:FormatAnnotation, find_module["https://json-schema.org/draft/2020-12/meta/format-annotation"])
      namespace.const_set(:Content,         find_module["https://json-schema.org/draft/2020-12/meta/content"])
      metaschema_module
    end

    name_vocab_schemas(self)
  end

  module JSONSchemaDraft202012::Core
  end
  module JSONSchemaDraft202012::Applicator
  end
  module JSONSchemaDraft202012::Unevaluated
  end
  module JSONSchemaDraft202012::Validation
  end
  module JSONSchemaDraft202012::MetaData
  end
  module JSONSchemaDraft202012::FormatAnnotation
  end
  module JSONSchemaDraft202012::Content
  end

  module JSONSchemaDraft202012
    # `$defs` property reader
    # @return [Base + JSONSchemaDraft202012::Defs, nil]
    def defs
      self['$defs']
    end
  end
end
