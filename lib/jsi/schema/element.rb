# frozen_string_literal: true

module JSI
  module Schema
    class Element
      # @yield [Schema::Element] self
      def initialize
        @actions = Hash.new(Util::EMPTY_ARY)

        yield(self)

        @actions.freeze
        freeze
      end

      # @param name [Symbol]
      # @yield perform the action
      # @return [void]
      def add_action(name, &block)
        raise(TypeError) unless name.is_a?(Symbol)

        @actions[name] = @actions[name].dup.push(block).freeze

        nil
      end
    end
  end
end
