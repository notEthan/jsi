# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    autoload :Draft04, 'jsi/schema/application/inplace_application/draft04'
    autoload :Draft06, 'jsi/schema/application/inplace_application/draft06'
    autoload :Draft07, 'jsi/schema/application/inplace_application/draft07'

    autoload :Ref, 'jsi/schema/application/inplace_application/ref'
    autoload :SomeOf, 'jsi/schema/application/inplace_application/someof'
    autoload :IfThenElse, 'jsi/schema/application/inplace_application/ifthenelse'
    autoload :Dependencies, 'jsi/schema/application/inplace_application/dependencies'

    # a set of inplace applicator schemas of this schema (from $ref, allOf, etc.) which apply to the
    # given instance.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param instance [Object] the instance to check any applicators against
    # @return [JSI::SchemaSet] matched applicator schemas
    def inplace_applicator_schemas(instance)
      SchemaSet.new(each_inplace_applicator_schema(instance))
    end

    # yields each inplace applicator schema which applies to the given instance.
    #
    # @param instance (see #inplace_applicator_schemas)
    # @param visited_refs [Enumerable<JSI::Schema::Ref>]
    # @yield [JSI::Schema]
    # @return [nil, Enumerator] an Enumerator if invoked without a block; otherwise nil
    def each_inplace_applicator_schema(instance, visited_refs: [], &block)
      return to_enum(__method__, instance, visited_refs: visited_refs) unless block

      catch(:jsi_application_done) do
        if schema_content.respond_to?(:to_hash)
          internal_inplace_applicate_keywords(instance, visited_refs, &block)
        else
          # self is the only applicator schema if there are no keywords
          yield self
        end
      end

      nil
    end
  end
end
