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

    STRUCT_NEW = Struct.singleton_class.instance_method(:new)
    private_constant(:STRUCT_NEW)

    HAS_KEYWORD_INIT = Struct.new(:_, keyword_init: true) && true rescue false
    private_constant(:HAS_KEYWORD_INIT)

    class << self
      # @return [Class]
      def subclass(*members)
        self_members = self.members rescue [] # NoMethodError on mri, NameError on truffle
        # Struct does not enable adding members to subclasses of its generated classes,
        # but that is still possible by binding Struct.new to the class and calling
        # that with both existing and new members.
        if HAS_KEYWORD_INIT
          STRUCT_NEW.bind(self).call(*self_members, *members, keyword_init: true)
        else
          STRUCT_NEW.bind(self).call(*self_members, *members)
        end
      end
    end

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
