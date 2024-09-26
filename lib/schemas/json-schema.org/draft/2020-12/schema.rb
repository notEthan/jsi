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
  end

  JSONSchemaDraft202012::Core       = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/core").jsi_schema_module
  JSONSchemaDraft202012::Applicator  = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/applicator").jsi_schema_module
  JSONSchemaDraft202012::Unevaluated  = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/unevaluated").jsi_schema_module
  JSONSchemaDraft202012::Validation    = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/validation").jsi_schema_module
  JSONSchemaDraft202012::MetaData       = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/meta-data").jsi_schema_module
  JSONSchemaDraft202012::FormatAnnotation = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/format-annotation").jsi_schema_module
  JSONSchemaDraft202012::Content         = jsi_registry.find("https://json-schema.org/draft/2020-12/meta/content").jsi_schema_module

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
