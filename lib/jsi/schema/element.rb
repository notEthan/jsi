# frozen_string_literal: true

module JSI
  module Schema
    class Element
      # @yield [Schema::Element] self
      def initialize
        @actions = Hash.new(Util::EMPTY_ARY)
        @required_before_element_selector = nil
        @depends_on_element_selector = nil

        yield(self)

        @actions.freeze
        freeze
      end

      # @return [Hash<Symbol, Array<Proc>>]
      attr_reader(:actions)

      # this element will be invoked before elements for which the result of the block is true-ish
      # @yieldparam [Schema::Element]
      # @yieldreturn [Boolean]
      def required_before_elements(&block)
        @required_before_element_selector = block
      end

      # this element will be invoked after elements for which the result of the block is true-ish
      # @yieldparam [Schema::Element]
      # @yieldreturn [Boolean]
      def depends_on_elements(&block)
        @depends_on_element_selector = block
      end

      # selects which of `elements` this element is required before
      def select_elements_self_is_required_before(elements)
        return(Util::EMPTY_ARY) unless @required_before_element_selector
        elements.select { |e| e != self && @required_before_element_selector.call(e) }.freeze
      end

      # selects which of `elements` this element depends on
      def select_elements_self_depends_on(elements)
        return(Util::EMPTY_ARY) unless @depends_on_element_selector
        elements.select { |e| e != self && @depends_on_element_selector.call(e) }.freeze
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
