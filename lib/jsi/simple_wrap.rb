# frozen_string_literal: true

module JSI
  dialect = Schema::Dialect.new(
    vocabularies: [
      Schema::Vocabulary.new(elements: [
        Schema::Element.new do |element|
          element.add_action(:inplace_applicate) { inplace_schema_applicate(schema) }
          element.add_action(:child_applicate) { child_schema_applicate(schema) }
        end,
      ]),
    ],
  )

  simple_wrap_metaschema = JSI.new_metaschema(nil, dialect: dialect)
  SimpleWrap = simple_wrap_metaschema.new_schema_module(Util::EMPTY_HASH)

  # SimpleWrap is a JSI schema module which recursively wraps nested structures
  module SimpleWrap
  end

  SimpleWrap::DIALECT = dialect
  SimpleWrap::METASCHEMA = simple_wrap_metaschema
end
