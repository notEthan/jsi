# frozen_string_literal: true

module JSI
  module Schema
    Issue = Util::AttrStruct[*%w(
      level
      message
      keyword
      schema
    )]

    class Issue
    end
  end
end
