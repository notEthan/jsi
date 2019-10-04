module JSI
  # including class MUST define
  # - #node_document [Object] returning the document
  # - #node_ptr [JSI::JSON::Pointer] returning a pointer for the node path in the document
  # - #document_root_node [JSI::PathedNode] returning a PathedNode pointing at the document root
  # - #parent_node [JSI::PathedNode] returning the parent node of this PathedNode
  # - #deref [JSI::PathedNode] following a $ref
  #
  # given these, this module represents the node in the document at the path.
  #
  # the node content (#node_content) is the result of evaluating the node document at the path.
  module PathedNode
    def node_content
      content = node_ptr.evaluate(node_document)
      content
    end

    def node_ptr_deref(&block)
      node_ptr.deref(node_document, &block)
    end
  end
end
