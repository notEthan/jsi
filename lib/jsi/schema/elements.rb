module JSI
  module Schema::Elements
    def self.element_map(&block)
      Util::MemoMap::Immutable.new(&block)
    end
  end

  module Schema::Elements
    # $ref in-place application
    autoload(:REF, 'jsi/schema/elements/ref')
  end
end
