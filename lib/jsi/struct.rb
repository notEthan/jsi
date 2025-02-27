# frozen_string_literal: true

module JSI
  # JSI::Struct adds to Struct:
  #
  # - always initialized by keywords
  # - .subclass enables hierarchical class inheritance with added members
  # - better pretty/inspect
  # @private
  class Struct < ::Struct
    include(Util::Pretty)

    HAS_KEYWORD_INIT = Struct.new(:_, keyword_init: true) && true rescue false
    private_constant(:HAS_KEYWORD_INIT)

    if !HAS_KEYWORD_INIT
      def initialize(h = {})
        super(*members.map { |m| h.key?(m) ? h.delete(m) : nil })
        raise(ArgumentError, "#{self.class} given non-members: #{h}") if !h.empty?
      end
    end

    def pretty_print(q)
      jsi_pp_object_group(q) do
        q.seplist(each_pair) do |k, v|
          q.text(k.to_s)
          q.text(': ')
          q.pp(v)
        end
      end
    end
  end
end
