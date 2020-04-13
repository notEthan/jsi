# frozen_string_literal: true

module JSI
  class Metaschema < JSI::Base
    include JSI::Schema
    include JSI::Schema::DescribesSchema

    def initialize(instance, jsi_metaschema_module: , **options)
      @jsi_metaschema_module = jsi_metaschema_module

      extend(jsi_metaschema_module)
      super(instance, options)
      extend(jsi_schema_module)
    end

    attr_reader :jsi_metaschema_module

    def described_schemas_jsi_metaschema_module
      jsi_metaschema_module
    end

    def jsi_schema_described_by
      jsi_metaschema_module
    end

    def jsi_schemas
      Set[self]
    end

    def jsi_fingerprint
      {class: JSI::Base, jsi_document: jsi_document, jsi_ptr: jsi_ptr, jsi_metaschema: true, jsi_metaschema_module: jsi_metaschema_module}
    end
  end
end
