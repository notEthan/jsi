# frozen_string_literal: true

module JSI
  # a module relating to objects that act like Hash or Array instances
  module Typelike
    # yields the content of the given param `object`. for objects which have a #jsi_modified_copy
    # method of their own (JSI::Base, JSI::MetaschemaNode) that method is invoked with the given
    # block. otherwise the given object itself is yielded.
    #
    # the given block must result in a modified copy of its block parameter
    # (not destructively modifying the yielded content).
    #
    # @yield [Object] the content of the given object. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [object.class] modified copy of the given object
    def self.modified_copy(object, &block)
      if object.respond_to?(:jsi_modified_copy)
        object.jsi_modified_copy(&block)
      else
        return yield(object)
      end
    end

    # recursive method to express the given argument object in json-compatible
    # types of Hash, Array, and basic types of String/boolean/numeric/nil. this
    # will raise TypeError if an object is given that is not a type that seems
    # to be expressable as json.
    #
    # similar effect could be achieved by requiring 'json/add/core' and using #as_json,
    # but I don't much care for how it represents classes that are
    # not naturally expressable in JSON, and prefer not to load its
    # monkey-patching.
    #
    # @param object [Object] the object to be converted to jsonifiability
    # @return [Array, Hash, String, Boolean, NilClass, Numeric] jsonifiable
    #   expression of param object
    # @raise [TypeError] when the object (or an object nested with a hash or
    #   array of object) cannot be expressed as json
    def self.as_json(object, *opt)
      if object.is_a?(JSI::PathedNode)
        as_json(object.jsi_node_content, *opt)
      elsif object.respond_to?(:to_hash)
        (object.respond_to?(:map) ? object : object.to_hash).map do |k, v|
          unless k.is_a?(Symbol) || k.respond_to?(:to_str)
            raise(TypeError, "json object (hash) cannot be keyed with: #{k.pretty_inspect.chomp}")
          end
          {k.to_s => as_json(v, *opt)}
        end.inject({}, &:update)
      elsif object.respond_to?(:to_ary)
        (object.respond_to?(:map) ? object : object.to_ary).map { |e| as_json(e, *opt) }
      elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| object.is_a?(c) }
        object
      elsif object.is_a?(Symbol)
        object.to_s
      elsif object.is_a?(Set)
        as_json(object.to_a, *opt)
      elsif object.respond_to?(:as_json)
        as_json(object.as_json(*opt), *opt)
      else
        raise(TypeError, "cannot express object as json: #{object.pretty_inspect.chomp}")
      end
    end
  end

  # a module of methods for objects which behave like Hash but are not Hash.
  #
  # this module is intended to be internal to JSI. no guarantees or API promises
  # are made for non-JSI classes including this module.
  module Hashlike
    # safe methods which can be delegated to #to_hash (which the includer is assumed to have defined).
    # 'safe' means, in this context, nondestructive - methods which do not modify the receiver.

    # methods which do not need to access the value.
    SAFE_KEY_ONLY_METHODS = %w(each_key empty? has_key? include? key? keys length member? size)
    SAFE_KEY_VALUE_METHODS = %w(< <= > >= any? assoc compact dig each_pair each_value fetch fetch_values has_value? invert key merge rassoc reject select to_h to_proc transform_values value? values values_at)
    DESTRUCTIVE_METHODS = %w(clear delete delete_if keep_if reject! replace select! shift)
    # these return a modified copy
    safe_modified_copy_methods = %w(compact)
    # select and reject will return a modified copy but need the yielded block variable value from #[]
    safe_kv_block_modified_copy_methods = %w(select reject)
    SAFE_METHODS = SAFE_KEY_ONLY_METHODS | SAFE_KEY_VALUE_METHODS
    safe_to_hash_methods = SAFE_METHODS - safe_modified_copy_methods - safe_kv_block_modified_copy_methods
    safe_to_hash_methods.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) { |*a, &b| to_hash.public_send(method_name, *a, &b) }
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
      else
        define_method(method_name) { |*a, **kw, &b| to_hash.public_send(method_name, *a, **kw, &b) }
      end
    end
    safe_modified_copy_methods.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) do |*a, &b|
          jsi_modified_copy do |object_to_modify|
            responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_hash
            responsive_object.public_send(method_name, *a, &b)
          end
        end
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
      else
        define_method(method_name) do |*a, **kw, &b|
          jsi_modified_copy do |object_to_modify|
            responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_hash
            responsive_object.public_send(method_name, *a, **kw, &b)
          end
        end
      end
    end
    safe_kv_block_modified_copy_methods.each do |method_name|
      define_method(method_name) do |**kw, &b|
        jsi_modified_copy do |object_to_modify|
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_hash
          responsive_object.public_send(method_name) do |k, _v|
            b.call(k, self[k, **kw])
          end
        end
      end
#      ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
    end

    # like [Hash#update](https://ruby-doc.org/core/Hash.html#method-i-update)
    # @param other [#to_hash] the other hash to update this hash from
    # @yield [key, oldval, newval] for entries with duplicate keys, the value of each duplicate key
    #   is determined by calling the block with the key, its value in self and its value in other.
    # @return self, updated with other
    # @raise [TypeError] when `other` does not respond to #to_hash
    def update(other, &block)
      unless other.respond_to?(:to_hash)
        raise(TypeError, "cannot update with argument that does not respond to #to_hash: #{other.pretty_inspect.chomp}")
      end
      self_respondingto_key = self.respond_to?(:key?) ? self : to_hash
      other.to_hash.each_pair do |key, value|
        if block && self_respondingto_key.key?(key)
          value = yield(key, self[key], value)
        end
        self[key] = value
      end
      self
    end

    alias_method :merge!, :update

    # like [Hash#merge](https://ruby-doc.org/core/Hash.html#method-i-merge)
    # @param other [#to_hash] the other hash to merge into this
    # @yield [key, oldval, newval] for entries with duplicate keys, the value of each duplicate key
    #   is determined by calling the block with the key, its value in self and its value in other.
    # @return duplicate of this hash with the other hash merged in
    # @raise [TypeError] when `other` does not respond to #to_hash
    def merge(other, &block)
      dup.update(other, &block)
    end

    # basically the same #inspect as Hash, but has the class name and, if responsive,
    # self's #jsi_object_group_text
    # @return [String]
    def inspect
      object_group_str = (respond_to?(:jsi_object_group_text) ? self.jsi_object_group_text : [self.class]).join(' ')
      "\#{<#{object_group_str}>#{self.map { |k, v| " #{k.inspect} => #{v.inspect}" }.join(',')}}"
    end

    alias_method :to_s, :inspect

    # pretty-prints a representation of this hashlike to the given printer
    # @return [void]
    def pretty_print(q)
      object_group_str = (respond_to?(:jsi_object_group_text) ? jsi_object_group_text : [self.class]).join(' ')
      q.text "\#{<#{object_group_str}>"
      q.group_sub {
        q.nest(2) {
          q.breakable(empty? ? '' : ' ')
          q.seplist(self, nil, :each_pair) { |k, v|
            q.group {
              q.pp k
              q.text ' => '
              q.pp v
            }
          }
        }
      }
      q.breakable ''
      q.text '}'
    end
  end

  # a module of methods for objects which behave like Array but are not Array.
  #
  # this module is intended to be internal to JSI. no guarantees or API promises
  # are made for non-JSI classes including this module.
  module Arraylike
    # safe methods which can be delegated to #to_ary (which the includer is assumed to have defined).
    # 'safe' means, in this context, nondestructive - methods which do not modify the receiver.

    # methods which do not need to access the element.
    SAFE_INDEX_ONLY_METHODS = %w(each_index empty? length size)
    # there are some ambiguous ones that are omitted, like #sort, #map / #collect.
    SAFE_INDEX_ELEMENT_METHODS = %w(| & * + - <=> abbrev at bsearch bsearch_index combination compact count cycle dig drop drop_while fetch find_index first include? index join last pack permutation product reject repeated_combination repeated_permutation reverse reverse_each rindex rotate sample select shelljoin shuffle slice sort take take_while transpose uniq values_at zip)
    DESTRUCTIVE_METHODS = %w(<< clear collect! compact! concat delete delete_at delete_if fill flatten! insert keep_if map! pop push reject! replace reverse! rotate! select! shift shuffle! slice! sort! sort_by! uniq! unshift)

    # methods (well, method) that returns a modified copy and doesn't need any handling of block variable(s)
    safe_modified_copy_methods = %w(compact)

    # methods that return a modified copy and do need handling of block variables
    safe_el_block_methods = %w(reject select)

    SAFE_METHODS = SAFE_INDEX_ONLY_METHODS | SAFE_INDEX_ELEMENT_METHODS
    safe_to_ary_methods = SAFE_METHODS - safe_modified_copy_methods - safe_el_block_methods
    safe_to_ary_methods.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) { |*a, &b| to_ary.public_send(method_name, *a, &b) }
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
      else
        define_method(method_name) { |*a, **kw, &b| to_ary.public_send(method_name, *a, **kw, &b) }
      end
    end
    safe_modified_copy_methods.each do |method_name|
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        define_method(method_name) do |*a, &b|
          jsi_modified_copy do |object_to_modify|
            responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_ary
            responsive_object.public_send(method_name, *a, &b)
          end
        end
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
      else
        define_method(method_name) do |*a, **kw, &b|
          jsi_modified_copy do |object_to_modify|
            responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_ary
            responsive_object.public_send(method_name, *a, **kw, &b)
          end
        end
      end
    end
    safe_el_block_methods.each do |method_name|
      define_method(method_name) do |**kw, &b|
        jsi_modified_copy do |object_to_modify|
          i = 0
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_ary
          responsive_object.public_send(method_name) do |_e|
            b.call(self[i, **kw]).tap { i += 1 }
          end
        end
      end
#      ruby2_keywords(method_name) if respond_to?(:ruby2_keywords)
    end

    # see [Array#assoc](https://ruby-doc.org/core/Array.html#method-i-assoc)
    def assoc(obj)
      # note: assoc implemented here (instead of delegated) due to inconsistencies in whether
      # other implementations expect each element to be an Array or to respond to #to_ary
      detect { |e| e.respond_to?(:to_ary) and e[0] == obj }
    end

    # see [Array#rassoc](https://ruby-doc.org/core/Array.html#method-i-rassoc)
    def rassoc(obj)
      # note: rassoc implemented here (instead of delegated) due to inconsistencies in whether
      # other implementations expect each element to be an Array or to respond to #to_ary
      detect { |e| e.respond_to?(:to_ary) and e[1] == obj }
    end

    # basically the same #inspect as Array, but has the class name and, if responsive,
    # self's #jsi_object_group_text
    # @return [String]
    def inspect
      object_group_str = (respond_to?(:jsi_object_group_text) ? jsi_object_group_text : [self.class]).join(' ')
      "\#[<#{object_group_str}>#{self.map { |e| ' ' + e.inspect }.join(',')}]"
    end

    alias_method :to_s, :inspect

    # pretty-prints a representation of this arraylike to the given printer
    # @return [void]
    def pretty_print(q)
      object_group_str = (respond_to?(:jsi_object_group_text) ? jsi_object_group_text : [self.class]).join(' ')
      q.text "\#[<#{object_group_str}>"
      q.group_sub {
        q.nest(2) {
          q.breakable(empty? ? '' : ' ')
          q.seplist(self, nil, :each) { |e|
            q.pp e
          }
        }
      }
      q.breakable ''
      q.text ']'
    end
  end
end
