module JSI
  module Schema::Elements
    def self.element_map(&block)
      Util::MemoMap::Immutable.new(&block)
    end
  end

  module Schema::Elements
  end
end
