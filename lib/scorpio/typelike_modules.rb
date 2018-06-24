module Scorpio
  module Typelike
    def self.modified_copy(other, &block)
      if other.respond_to?(:modified_copy)
        other.modified_copy(&block)
      else
        return yield(other)
      end
    end

    # I could require 'json/add/core' and use #as_json but I like this better.
    def self.as_json(object)
      if object.respond_to?(:to_hash)
        object.map do |k, v|
          unless k.is_a?(Symbol) || k.respond_to?(:to_str)
            raise(TypeError, "json object (hash) cannot be keyed with: #{k.pretty_inspect.chomp}")
          end
          {k.to_s => as_json(v)}
        end.inject({}, &:update)
      elsif object.respond_to?(:to_ary)
        object.map { |e| as_json(e) }
      elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| object.is_a?(c) }
        object
      elsif object.is_a?(Symbol)
        object.to_s
      elsif object.is_a?(Set)
        as_json(object.to_a)
      elsif object.respond_to?(:as_json)
        as_json(object.as_json)
      else
        raise(TypeError, "cannot express object as json: #{object.pretty_inspect.chomp}")
      end
    end
  end
  module Hashlike
    include Enumerable

    # safe methods which can be delegated to #to_hash (which the includer is assumed to have defined).
    # 'safe' means, in this context, nondestructive - methods which do not modify the receiver.

    # methods which do not need to access the value.
    SAFE_KEY_ONLY_METHODS = %w(each_key empty? has_key? include? key? keys length member? size)
    SAFE_KEY_VALUE_METHODS = %w(< <= > >= any? assoc compact dig each_pair each_value fetch fetch_values has_value? invert key merge rassoc reject select to_h to_proc transform_values value? values values_at)
    DESTRUCTIVE_METHODS = %w(clear delete delete_if keep_if reject! replace select! shift)
    # these return a modified copy
    safe_modified_copy_methods = %w(compact merge)
    # select and reject will return a modified copy but need the yielded block variable value from #[]
    safe_kv_block_modified_copy_methods = %w(select reject)
    SAFE_METHODS = SAFE_KEY_ONLY_METHODS | SAFE_KEY_VALUE_METHODS
    safe_to_hash_methods = SAFE_METHODS - safe_modified_copy_methods - safe_kv_block_modified_copy_methods
    safe_to_hash_methods.each do |method_name|
      define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
    end
    safe_modified_copy_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        Scorpio::Typelike.modified_copy(self) do |object_to_modify|
          object_to_modify.public_send(method_name, *a, &b)
        end
      end
    end
    safe_kv_block_modified_copy_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        Scorpio::Typelike.modified_copy(self) do |object_to_modify|
          object_to_modify.public_send(method_name, *a) do |k, _v|
            b.call(k, self[k])
          end
        end
      end
    end

    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#{<#{self.class.to_s}#{object_group_text}>#{empty? ? '' : ' '}#{self.map { |k, v| "#{k.inspect} => #{v.inspect}" }.join(', ')}}"
    end

    def to_s
      inspect
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#{<#{obj.class.to_s}#{object_group_text}>"
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
    include Enumerable

    # safe methods which can be delegated to #to_ary (which the includer is assumed to have defined).
    # 'safe' means, in this context, nondestructive - methods which do not modify the receiver.

    # methods which do not need to access the element.
    SAFE_INDEX_ONLY_METHODS = %w(each_index empty? length size)
    # there are some ambiguous ones that are omitted, like #sort, #map / #collect.
    SAFE_INDEX_ELEMENT_METHODS = %w(| & * + - <=> abbrev assoc at bsearch bsearch_index combination compact count cycle dig drop drop_while fetch find_index first include? index join last pack permutation product reject repeated_combination repeated_permutation reverse reverse_each rindex rotate sample select shelljoin shuffle slice sort take take_while transpose uniq values_at zip)
    DESTRUCTIVE_METHODS = %w(<< clear collect! compact! concat delete delete_at delete_if fill flatten! insert keep_if map! pop push reject! replace reverse! rotate! select! shift shuffle! slice! sort! sort_by! uniq! unshift)

    # methods (well, method) that returns a modified copy and doesn't need any handling of block variable(s)
    safe_modified_copy_methods = %w(compact)

    # methods that return a modified copy and do need handling of block variables
    safe_el_block_methods = %w(reject select)

    SAFE_METHODS = SAFE_INDEX_ONLY_METHODS | SAFE_INDEX_ELEMENT_METHODS
    safe_to_ary_methods = SAFE_METHODS - safe_modified_copy_methods - safe_el_block_methods
    safe_to_ary_methods.each do |method_name|
      define_method(method_name) { |*a, &b| to_ary.public_send(method_name, *a, &b) }
    end
    safe_modified_copy_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        Scorpio::Typelike.modified_copy(self) do |object_to_modify|
          object_to_modify.public_send(method_name, *a, &b)
        end
      end
    end
    safe_el_block_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        Scorpio::Typelike.modified_copy(self) do |object_to_modify|
          i = 0
          object_to_modify.public_send(method_name, *a) do |_e|
            b.call(self[i]).tap { i += 1 }
          end
        end
      end
    end

    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#[<#{self.class.to_s}#{object_group_text}>#{empty? ? '' : ' '}#{self.map { |e| e.inspect }.join(', ')}]"
    end

    def to_s
      inspect
    end

    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#[<#{obj.class.to_s}#{object_group_text}>"
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
