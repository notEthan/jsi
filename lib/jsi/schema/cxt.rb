# frozen_string_literal: true

module JSI
  module Schema
    Cxt = Util::AttrStruct[*%w(
      schema
      abort
    )]

    # @!attribute schema
    #   The schema invoking an action in this context
    #   @return [JSI::Schema]
    class Cxt
      #chkbug def initialize(attributes = {})
      #chkbug   super
      #chkbug   @current_element = nil
      #chkbug end

      def subschema(subptr)
        schema.subschema(subptr)
      end

      def schema_content
        schema.jsi_node_content
      end

      #chkbug def using_element(element)
      #chkbug   raise if @current_element
      #chkbug   @current_element = element
      #chkbug   begin
      #chkbug     return yield
      #chkbug   ensure
      #chkbug     @current_element = nil
      #chkbug   end
      #chkbug end

      def keyword?(keyword)
        #chkbug unless @current_element.keywords.include?(keyword)
        #chkbug   raise(Bug, "Element using undeclared keyword: #{keyword.inspect}")
        #chkbug end
        schema.keyword?(keyword)
      end

      # @return [Boolean]
      def keyword_value_hash?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_hash)
      end

      # @return [Boolean]
      def keyword_value_ary?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_ary)
      end

      # @return [Boolean]
      def keyword_value_str?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_str)
      end

      # @return [Boolean]
      def keyword_value_bool?(keyword)
        keyword?(keyword) && (schema_content[keyword] == true || schema_content[keyword] == false)
      end

      # @return [Boolean]
      def keyword_value_numeric?(keyword)
        keyword?(keyword) && schema_content[keyword].is_a?(Numeric)
      end

      # @return [Boolean]
      def internal_integer?(value)
        schema.internal_integer?(value)
      end
    end

    class Cxt
      autoload(:InplaceApplication, 'jsi/schema/cxt/inplace_application')
      autoload(:ChildApplication, 'jsi/schema/cxt/child_application')
    end

    Cxt::Block = Cxt.subclass('block')

    # @!attribute block
    #   @return [#call]
    class Cxt::Block
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        def cxt_yield(*a)
          block.call(*a)
        end
      else
        def cxt_yield(*a, **kw)
          block.call(*a, **kw)
        end
      end
    end
  end
end
