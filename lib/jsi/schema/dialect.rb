# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      include(Util::Pretty)

      # @param id [#to_str, nil]
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(id: nil, vocabularies: )
        @id = Util.uri(id, nnil: false, yabs: true, ynorm: true)
        @vocabularies = Set.new(vocabularies).freeze

        elements = vocabularies.map(&:elements).inject(Set.new, &:merge)

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

        @elements = []

        until elements.empty?
          sort_element = elements.detect do |element|
            dependencies[element].all? { |req_el| @elements.include?(req_el) }
          end || fail(Bug)
          @elements.push(sort_element)
          elements.delete(sort_element)
        end

        @elements.freeze

        @elements_performing = Hash.new(Util::EMPTY_ARY)
        action_names = @elements.map { |e| e.actions.each_key }.inject(Set.new, &:+).freeze
        action_names.each do |action_name|
          @elements_performing[action_name] = @elements.select { |e| !e.actions[action_name].empty? }.freeze
        end
        @elements_performing.freeze

        freeze
      end

      # @return [Addressable::URI, nil]
      attr_reader(:id)

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)

      # @return [Array<Schema::Element>]
      attr_reader(:elements)

      # Invoke the indicated action of each Element on the given context
      # @param action_name [Symbol]
      # @param cxt [Schema::Cxt] the `self` of the action
      # @return given `cxt`
      def invoke(action_name, cxt)
        @elements_performing[action_name].each do |element|
          element.actions[action_name].each do |action|
            cxt.instance_exec(&action)
            return(cxt) if cxt.abort
          end
        end

        cxt
      end

      # @param q
      def pretty_print(q)
        q.text('#<')
        q.text(self.class.name)
        if id
          q.text(' ')
          q.text("id: <#{id}>")
        end
        q.text('>')
      end
    end
  end
end
