# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(vocabularies: )
        @vocabularies = Set.new(vocabularies).freeze
        @elements = vocabularies.map(&:elements).inject(Set.new, &:merge).freeze

        freeze
      end

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)

      # @return [Set<Schema::Element>]
      attr_reader(:elements)

      # Invoke the indicated action of each Element on the given context
      # @param action_name [Symbol]
      # @param cxt [Schema::Cxt] the `self` of the action
      # @return given `cxt`
      def invoke(action_name, cxt)
        invoked_elements = Set[]
        uninvoked_elements = elements.dup

        # key element depends on each element of its value
        dependencies = Hash.new { |h, k| h[k] = Set[] }
        elements.each do |element|
          element.select_elements_self_is_required_before(elements).each do |required_before_element|
            # element will be invoked before required_before_element
            dependencies[required_before_element] << element
          end

          element.select_elements_self_depends_on(elements).each do |depends_on_element|
            # element will be invoked after depends_on_element
            dependencies[element] << depends_on_element
          end
        end

        until uninvoked_elements.empty?
          invoke_element = uninvoked_elements.detect do |element|
            dependencies[element].all? { |req_el| invoked_elements.include?(req_el) }
          end || raise(Bug)
          invoke_element.actions[action_name].each do |action|
            cxt.instance_exec(&action)
          end
          invoked_elements.add(invoke_element)
          uninvoked_elements.delete(invoke_element)
        end

        cxt
      end
    end
  end
end
