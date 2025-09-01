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

  find_module = proc { |uri| JSONSchemaDraft202012.schema.jsi_registry.find(uri).jsi_schema_module }
  JSONSchemaDraft202012::Core       = find_module["https://json-schema.org/draft/2020-12/meta/core"]
  JSONSchemaDraft202012::Applicator  = find_module["https://json-schema.org/draft/2020-12/meta/applicator"]
  JSONSchemaDraft202012::Unevaluated  = find_module["https://json-schema.org/draft/2020-12/meta/unevaluated"]
  JSONSchemaDraft202012::Validation    = find_module["https://json-schema.org/draft/2020-12/meta/validation"]
  JSONSchemaDraft202012::MetaData       = find_module["https://json-schema.org/draft/2020-12/meta/meta-data"]
  JSONSchemaDraft202012::FormatAnnotation = find_module["https://json-schema.org/draft/2020-12/meta/format-annotation"]
  JSONSchemaDraft202012::Content         = find_module["https://json-schema.org/draft/2020-12/meta/content"]

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
