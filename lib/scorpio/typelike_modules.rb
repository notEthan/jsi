module Scorpio
  module Hashlike
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
