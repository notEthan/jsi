# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      include(Util::Pretty)

      # @param id [#to_str, nil]
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(id: nil, vocabularies: , **config)
        @id = Util.uri(id, nnil: false, yabs: true, ynorm: true)
        @vocabularies = Set.new(vocabularies).freeze
        @config = config.freeze

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

        @bootstrap_schema_class = bootstrap_schema_class_compute

        @bootstrap_schema_map = Util::MemoMap::Immutable.new { |document: , **kw| bootstrap_schema_class.new(document, **kw) }

        freeze
      end

      # @return [URI, nil]
      attr_reader(:id)

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)

      # @return [Hash]
      attr_reader(:config)

      # @return [Array<Schema::Element>]
      attr_reader(:elements)

      # a subclass of {MetaSchemaNode::BootstrapSchema} for this Dialect
      # @api private
      # @return [Class subclass of MetaSchemaNode::BootstrapSchema]
      attr_reader(:bootstrap_schema_class)

      # @api private
      # @return [MetaSchemaNode::BootstrapSchema]
      def bootstrap_schema(document, **kw)
        @bootstrap_schema_map[document: document, **kw]
      end

      # Invoke the indicated action of each Element on the given context
      # @param action_name [Symbol]
      # @param cxt [Schema::Cxt] the `self` of the action
      # @return given `cxt`
      def invoke(action_name, cxt)
        @elements_performing[action_name].each do |element|
          #chkbug cxt.using_element(element) do
          element.actions[action_name].each do |action|
            cxt.instance_exec(&action)
            return(cxt) if cxt.abort
          end
          #chkbug end
        end

        cxt
      end

      # @param q
      def pretty_print(q)
        pres = [self.class.name]
        pres.push(-"id: <#{id}>") if id
        jsi_pp_object_group(q, pres.freeze)
      end

      private

      def bootstrap_schema_class_compute
        dialect = self
        Class.new(MetaSchemaNode::BootstrapSchema) do
          define_singleton_method(:described_dialect) { dialect }
          define_method(:dialect) { dialect }

          self
        end
      end
    end
  end
end
