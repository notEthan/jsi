# frozen_string_literal: true

module JSI
  class Set < ::Set
    include(Util::Pretty)

    def pretty_print(q)
      q.text(self.class.to_s)
      q.text('[')
      q.group do
        q.nest(2) do
          q.breakable('')
          q.seplist(self) do |e|
            q.pp(e)
          end
        end
        q.breakable('')
      end
      q.text(']')
    end
  end
end
