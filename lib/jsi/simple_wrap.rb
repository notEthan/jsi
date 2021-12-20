# frozen_string_literal: true

module JSI
  dialect = Schema::Dialect.new(
    vocabularies: [
      Schema::Vocabulary.new(elements: [
      ]),
    ],
  )

  simple_wrap_implementation = Module.new do
    define_method(:dialect) do
      dialect
    end

    def internal_child_applicate_keywords(token, instance)
      yield self
    end

    def internal_inplace_applicate_keywords(instance, visited_refs)
      yield self
    end

    def internal_validate_keywords(result_builder)
    end
  end

  simple_wrap_metaschema = JSI.new_metaschema(nil, schema_implementation_modules: [simple_wrap_implementation])
  SimpleWrap = simple_wrap_metaschema.new_schema_module(Util::EMPTY_HASH)

  # SimpleWrap is a JSI schema module which recursively wraps nested structures
  module SimpleWrap
  end

  SimpleWrap::Implementation = simple_wrap_implementation
  SimpleWrap::DIALECT = dialect
  SimpleWrap::METASCHEMA = simple_wrap_metaschema
end
