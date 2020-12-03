# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    # checks this schema for applicators ($ref, allOf, etc.) which should be applied to the given instance.
    # returns these as a Set of {JSI::Schema}s.
    #
    # the returned set will contain this schema itself, unless this schema contains a $ref keyword.
    #
    # @param other_instance [Object] the instance to check any applicators against
    # @return [Set<JSI::Schema>] matched applicator schemas
    def match_to_instance(other_instance)
      jsi_ptr.schema_match_ptrs_to_instance(jsi_document, other_instance).map do |ptr|
        resource_root_subschema(ptr)
      end.to_set
    end
  end
end
