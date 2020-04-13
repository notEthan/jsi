# frozen_string_literal: true

module JSI
  class BasicSchema



    # @private
    # @return [Array<String>]
    def object_group_text
      [
        self.class.inspect,
        schema_uri || ptr.uri,
      ]
    end
  end
end
