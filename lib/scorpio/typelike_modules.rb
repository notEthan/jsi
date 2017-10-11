module Scorpio
  module Hashlike
    def inspect
      "\#{<#{self.class.name}> #{self.map { |k, v| "#{k.inspect} => #{v.inspect}" }.join(', ')}}"
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#{<#{obj.class.name}>"
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
      "\#[<#{self.class.name}> #{self.map { |e| e.inspect }.join(', ')}]"
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#[<#{obj.class.name}>"
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
