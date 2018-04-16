module Scorpio
  module Hashlike
    # safe methods which can be delegated to #to_hash (which the includer is assumed to have defined).
    # 'safe' means, in this context, nondestructive - methods which do not modify the receiver.

    # methods which do not need to access the value.
    SAFE_KEY_ONLY_METHODS = %w(each_key empty? has_key? include? key? keys length member? size)
    SAFE_KEY_VALUE_METHODS = %w(< <= > >= any? assoc compact dig each_pair each_value fetch fetch_values has_value? invert key merge rassoc reject select to_h to_proc transform_values value? values values_at)
    DESTRUCTIVE_METHODS = %w(clear delete delete_if keep_if reject! replace select! shift)
    # methods which return a modified copy, which you'd expect to be of the same class as the receiver.
    # there are some ambiguous ones that are omitted, like #invert.
    SAFE_MODIFIED_COPY_METHODS = %w(compact merge reject select transform_values)

    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#{<#{self.class.name}#{object_group_text}> #{self.map { |k, v| "#{k.inspect} => #{v.inspect}" }.join(', ')}}"
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#{<#{obj.class.name}#{object_group_text}>"
        group_sub {
          nest(2) {
            breakable(obj.any? { true } ? ' ' : '')
            seplist(obj, nil, :each_pair) { |k, v|
              group {
                pp k
                text ' => '
                pp v
              }
            }
          }
        }
        breakable ''
        text '}'
      end
    end
  end
  module Arraylike
    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#[<#{self.class.name}#{object_group_text}> #{self.map { |e| e.inspect }.join(', ')}]"
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#[<#{obj.class.name}#{object_group_text}>"
        group_sub {
          nest(2) {
            breakable(obj.any? { true } ? ' ' : '')
            seplist(obj, nil, :each) { |e|
              pp e
            }
          }
        }
        breakable ''
        text ']'
      end
    end
  end
end
