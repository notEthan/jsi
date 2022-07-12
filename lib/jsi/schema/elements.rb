module JSI
  module Schema::Elements
    def self.element_map(&block)
      Util::MemoMap::Immutable.new(&block)
    end
  end

  module Schema::Elements
    # the schema itself
    autoload(:SELF, 'jsi/schema/elements/self')

    # $schema
    autoload(:XSCHEMA, 'jsi/schema/elements/xschema')

    # id
    autoload(:ID, 'jsi/schema/elements/id')

    # definitions
    autoload(:DEFINITIONS, 'jsi/schema/elements/definitions')

    # $ref in-place application
    autoload(:REF, 'jsi/schema/elements/ref')

    # in-place subschema application
    autoload(:IF_THEN_ELSE, 'jsi/schema/elements/if_then_else')
    autoload(:DEPENDENCIES, 'jsi/schema/elements/dependencies')
    autoload(:ALL_OF, 'jsi/schema/elements/some_of')
    autoload(:ANY_OF, 'jsi/schema/elements/some_of')
    autoload(:ONE_OF, 'jsi/schema/elements/some_of')

    # child subschema application
    autoload(:ITEMS, 'jsi/schema/elements/items')
    autoload(:CONTAINS, 'jsi/schema/elements/contains')
    autoload(:PROPERTIES, 'jsi/schema/elements/properties')

    # property names subschema application
    autoload(:PROPERTY_NAMES, 'jsi/schema/elements/property_names')

    # any type validation
    autoload(:TYPE, 'jsi/schema/elements/type')
    autoload(:ENUM, 'jsi/schema/elements/enum')
    autoload(:CONST, 'jsi/schema/elements/const')
    autoload(:NOT, 'jsi/schema/elements/not')

    # object validation
    autoload(:REQUIRED,    'jsi/schema/elements/required')
    autoload(:MAX_PROPERTIES, 'jsi/schema/elements/object_validation')
    autoload(:MIN_PROPERTIES, 'jsi/schema/elements/object_validation')

    # array validation
    autoload(:MAX_ITEMS, 'jsi/schema/elements/array_validation')
    autoload(:MIN_ITEMS, 'jsi/schema/elements/array_validation')
    autoload(:UNIQUE_ITEMS, 'jsi/schema/elements/array_validation')

    # string validation
    autoload(:MAX_LENGTH, 'jsi/schema/elements/string_validation')
    autoload(:MIN_LENGTH, 'jsi/schema/elements/string_validation')
    autoload(:PATTERN, 'jsi/schema/elements/pattern')

    # numeric validation
    autoload(:MULTIPLE_OF, 'jsi/schema/elements/numeric')
    autoload(:MAXIMUM,           'jsi/schema/elements/numeric')
    autoload(:EXCLUSIVE_MAXIMUM, 'jsi/schema/elements/numeric')
    autoload(:MINIMUM,           'jsi/schema/elements/numeric')
    autoload(:EXCLUSIVE_MINIMUM, 'jsi/schema/elements/numeric')
    autoload(:MAXIMUM_BOOLEAN_EXCLUSIVE, 'jsi/schema/elements/numeric_draft04')
    autoload(:MINIMUM_BOOLEAN_EXCLUSIVE, 'jsi/schema/elements/numeric_draft04')

    # content
    autoload(:CONTENT_ENCODING, 'jsi/schema/elements/content_encoding')
    autoload(:CONTENT_MEDIA_TYPE, 'jsi/schema/elements/content_media_type')

    # metadata
    autoload(:DEFAULT, 'jsi/schema/elements/default')
  end
end
