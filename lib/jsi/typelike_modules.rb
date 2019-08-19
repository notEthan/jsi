module JSI
  # a module relating to objects that act like Hash or Array instances
  module Typelike
    # yields the content of the given param `object`. for objects which have a
    # #modified_copy method of their own (JSI::Base, JSI::JSON::Node) that
    # method is invoked with the given block. otherwise the given object itself
    # is yielded.
    #
    # the given block must result in a modified copy of its block parameter
    # (not destructively modifying the yielded content).
    #
    # @yield [Object] the content of the given object. the block should result
    #   in a (nondestructively) modified copy of this.
    # @return [object.class] modified copy of the given object
    def self.modified_copy(object, &block)
      if object.respond_to?(:modified_copy)
        object.modified_copy(&block)
      else
        return yield(object)
      end
    end

    # recursive method to express the given argument object in json-compatible
    # types of Hash, Array, and basic types of String/boolean/numeric/nil. this
    # will raise TypeError if an object is given that is not a type that seems
    # to be expressable as json.
    #
    # similar effect could be achieved by requiring 'json/add/core' and using
    # #as_json, but I don't much care for how it represents classes that are
    # not naturally expressable in JSON, and prefer not to load its
    # monkey-patching.
    #
    # @param object [Object] the object to be converted to jsonifiability
    # @return [Array, Hash, String, Boolean, NilClass, Numeric] jsonifiable
    #   expression of param object
    # @raise [TypeError] when the object (or an object nested with a hash or
    #   array of object) cannot be expressed as json
    def self.as_json(object, *opt)
      if object.is_a?(JSI::Schema)
        as_json(object.schema_object, *opt)
      elsif object.is_a?(JSI::Base)
        as_json(object.instance, *opt)
      elsif object.is_a?(JSI::JSON::Node)
        as_json(object.content, *opt)
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
        JSI::Typelike.modified_copy(self) do |object_to_modify|
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_hash
          responsive_object.public_send(method_name, *a, &b)
        end
      end
    end
    safe_kv_block_modified_copy_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        JSI::Typelike.modified_copy(self) do |object_to_modify|
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_hash
          responsive_object.public_send(method_name, *a) do |k, _v|
            b.call(k, self[k])
          end
        end
      end
    end

    # @return [String] basically the same #inspect as Hash, but has the
    #   class name and, if responsive, self's #object_group_text
    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#{<#{self.class}#{object_group_text}>#{empty? ? '' : ' '}#{self.map { |k, v| "#{k.inspect} => #{v.inspect}" }.join(', ')}}"
    end

    # @return [String] see #inspect
    def to_s
      inspect
    end

    # pretty-prints a representation this node to the given printer
    # @return [void]
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#{<#{obj.class}#{object_group_text}>"
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
        JSI::Typelike.modified_copy(self) do |object_to_modify|
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_ary
          responsive_object.public_send(method_name, *a, &b)
        end
      end
    end
    safe_el_block_methods.each do |method_name|
      define_method(method_name) do |*a, &b|
        JSI::Typelike.modified_copy(self) do |object_to_modify|
          i = 0
          responsive_object = object_to_modify.respond_to?(method_name) ? object_to_modify : object_to_modify.to_ary
          responsive_object.public_send(method_name, *a) do |_e|
            b.call(self[i]).tap { i += 1 }
          end
        end
      end
    end

    # @return [String] basically the same #inspect as Array, but has the
    #   class name and, if responsive, self's #object_group_text
    def inspect
      object_group_text = respond_to?(:object_group_text) ? ' ' + self.object_group_text : ''
      "\#[<#{self.class}#{object_group_text}>#{empty? ? '' : ' '}#{self.map { |e| e.inspect }.join(', ')}]"
    end

    # @return [String] see #inspect
    def to_s
      inspect
    end

    # pretty-prints a representation this node to the given printer
    # @return [void]
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        object_group_text = obj.respond_to?(:object_group_text) ? ' ' + obj.object_group_text : ''
        text "\#[<#{obj.class}#{object_group_text}>"
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
