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
        elements.each do |element|
          element.actions[action_name].each do |action|
            cxt.instance_exec(&action)
          end
        end

        cxt
      end
    end
  end
end
