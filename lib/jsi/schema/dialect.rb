# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      include(Util::Pretty)

      # @param id [#to_str, nil]
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(id: nil, vocabularies: , **conf)
        @id = Util.uri(id, nnil: false, yabs: true, ynorm: true)
        @vocabularies = Set.new(vocabularies).freeze
        @conf = conf.freeze

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

        @actions = Hash.new(Util::EMPTY_ARY)
        action_names = @elements.map { |e| e.actions.each_key }.inject(Set.new, &:merge).freeze
        action_names.each do |action_name|
          @actions[action_name] = @elements.map { |e| e.actions[action_name] }.inject([], &:concat).freeze
        end
        @actions.freeze

        @bootstrap_schema_class = bootstrap_schema_class_compute

        # Bootstrap schemas are memoized in nested hashes.
        # The outer hash is keyed by document, compared by identity, because hashing the document
        # is expensive and there aren't typically multiple instances of the same document
        # (and if there are, it is no problem for them to map to different bootstrap schemas).
        # The inner hash is keyed by other keyword params to MetaSchemaNode::BootstrapSchema#initialize,
        # not by identity, as those use different instances but are cheaper to hash.
        @bootstrap_schema_map = Hash.new do |dochash, document|
          dochash[document] = Hash.new do |paramhash, kw|
            paramhash[kw] = bootstrap_schema_class.new(document, **kw)
          end
        end
        @bootstrap_schema_map.compare_by_identity

        freeze
      end

      # @return [URI, nil]
      attr_reader(:id)

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)

      # @return [Hash]
      attr_reader(:conf)

      # @return [Array<Schema::Element>]
      attr_reader(:elements)

      # a subclass of {MetaSchemaNode::BootstrapSchema} for this Dialect
      # @api private
      # @return [Class subclass of MetaSchemaNode::BootstrapSchema]
      attr_reader(:bootstrap_schema_class)

      # @api private
      # @return [MetaSchemaNode::BootstrapSchema]
      def bootstrap_schema(document, **kw)
        @bootstrap_schema_map[document][kw]
      end

      # Invoke the indicated action of each Element on the given context
      # @param action_name [Symbol]
      # @param cxt [Schema::Cxt] the `self` of the action
      # @return given `cxt`
      def invoke(action_name, cxt)
        @actions[action_name].each do |action|
            cxt.instance_exec(&action)
            return(cxt) if cxt.abort
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
        end
      end
    end
  end
end
