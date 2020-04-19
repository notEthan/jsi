# frozen_string_literal: true

module JSI
  module Validation
    Error = Util::AttrStruct[*%w(
      message
      keyword
      schema
      instance_ptr
      instance_document
    )]

    # a validation error of a schema instance against a schema
    class Error
    end
  end
end
