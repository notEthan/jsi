module JSI
  module Schema::Elements
    def self.element_map(&block)
      Util::MemoMap::Immutable.new(&block)
    end
  end

  module Schema::Elements
    # the schema itself
    autoload(:SELF, 'jsi/schema/elements/self')

    # $ref in-place application
    autoload(:REF, 'jsi/schema/elements/ref')

    # in-place subschema application
    autoload(:IF_THEN_ELSE, 'jsi/schema/elements/if_then_else')
    autoload(:DEPENDENCIES, 'jsi/schema/elements/dependencies')
    autoload(:ALL_OF, 'jsi/schema/elements/some_of')
    autoload(:ANY_OF, 'jsi/schema/elements/some_of')
    autoload(:ONE_OF, 'jsi/schema/elements/some_of')
  end
end
