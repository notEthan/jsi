# frozen_string_literal: true

module JSI
  # JSI::Util::Private classes, modules, constants, and methods are internal, and will be added and removed without warning.
  #
  # @api private
  module Util::Private
    autoload :AttrStruct, 'jsi/util/private/attr_struct'
    autoload :MemoMap, 'jsi/util/private/memo_map'

    extend self

    EMPTY_ARY = [].freeze

    EMPTY_HASH = {}.freeze

    EMPTY_SET = Set[].freeze

    CLASSES_ALWAYS_FROZEN = Set[TrueClass, FalseClass, NilClass, Integer, Float, BigDecimal, Rational, Symbol].freeze

    # is a hash as the last argument passed to keyword params? (false in ruby 3; true before - generates
    # a warning in 2.7 but no way to make 2.7 behave like 3 so the warning is useless)
    #
    # TODO remove eventually (keyword argument compatibility)
    LAST_ARGUMENT_AS_KEYWORD_PARAMETERS = begin
      if Object.const_defined?(:Warning)
        warn = ::Warning.instance_method(:warn)
        ::Warning.send(:remove_method, :warn)
        ::Warning.send(:define_method, :warn) { |*, **| }
      end

      -> (k: ) { k }[{k: nil}]
      true
    rescue ArgumentError
      false
    ensure
      if Object.const_defined?(:Warning)
        ::Warning.send(:remove_method, :warn)
        ::Warning.send(:define_method, :warn, warn)
      end
    end

    # we won't use #to_json on classes where it is defined by
    # JSON::Ext::Generator::GeneratorMethods / JSON::Pure::Generator::GeneratorMethods
    # this is a bit of a kluge and disregards any singleton class to_json, but it will do.
    USE_TO_JSON_METHOD = Hash.new do |h, klass|
      h[klass] = klass.method_defined?(:to_json) &&
        klass.instance_method(:to_json).owner.name !~ /\AJSON:.*:GeneratorMethods\b/
    end

    RUBY_REJECT_NAME_CODEPOINTS = [
      0..31, # C0 control chars
      %q( !"#$%&'()*+,-./:;<=>?@[\\]^`{|}~).each_codepoint, # printable special chars (note: "_" not included)
      127..159, # C1 control chars
    ].inject(Set[], &:merge).freeze

    RUBY_REJECT_NAME_RE = Regexp.new('[' + Regexp.escape(RUBY_REJECT_NAME_CODEPOINTS.to_a.pack('U*')) + ']+').freeze

    # is the given name ok to use as a ruby method name?
    def ok_ruby_method_name?(name)
      # must be a string
      return false unless name.respond_to?(:to_str)
      # must not begin with a digit
      return false if name =~ /\A[0-9]/
      # must not contain special or control characters
      return false if name =~ RUBY_REJECT_NAME_RE

      return true
    end

    def const_name_from_parts(parts, join: '')
      parts = parts.map do |part|
        part = part.dup
        part[/\A[^a-zA-Z]*/] = ''
        part[0] = part[0].upcase if part[0]
        part.gsub!(RUBY_REJECT_NAME_RE, '_')
        part
      end
      if !parts.all?(&:empty?)
        parts.reject(&:empty?).join(join).freeze
      else
        nil
      end
    end

    # string or URI → frozen URI
    # @param nnil must not be nil
    # @param yabs must be absolute
    # @param ynorm must be normalized
    # @param tonorm normalize returned URI
    # @return [URI, nil]
    def uri(uri, nnil: true, yabs: false, ynorm: false, tonorm: false)
      return nil if !nnil && uri.nil?
      if uri.is_a?(URI)
        auri = uri
      elsif uri.is_a?(String) || uri.respond_to?(:to_str)
        auri = URI.parse(uri)
      else
        raise(URIError, "URI is not a string: #{uri.inspect}")
      end
      if yabs && !auri.scheme
        raise(URIError, "URI must be an absolute URI. got: #{uri.inspect}")
      end
      if yabs && auri.fragment
        if auri.fragment.empty?
          auri = auri.merge(fragment: nil)
        else
          raise(URIError, "URI must have no fragment. got: #{uri.inspect}")
        end
      end
      if ynorm && uri.to_str != auri.normalize.to_s
        raise(URIError, "URI must be in normalized form. got: #{uri.inspect}; normalized: #{auri.normalize.to_s.inspect}")
      end
      auri = auri.normalize if tonorm
      auri
    end

    # this is the Y-combinator, which allows anonymous recursive functions. for a simple example,
    # to define a recursive function to return the length of an array:
    #
    #     length = ycomb do |len|
    #       proc { |list| list == [] ? 0 : 1 + len.call(list[1..-1]) }
    #     end
    #
    #     length.call([0])
    #     # => 1
    #
    # see https://en.wikipedia.org/wiki/Fixed-point_combinator#Y_combinator
    # and chapter 9 of the little schemer, available as the sample chapter at
    # https://felleisen.org/matthias/BTLS-index.html
    def ycomb
      proc { |f| f.call(f) }.call(proc { |f| yield proc { |*x| f.call(f).call(*x) } })
    end

    def require_jmespath
      return if instance_variable_defined?(:@jmespath_required)
      begin
        require 'jmespath'
      rescue ::LoadError => e
        # :nocov:
        msg = [
          "please install and/or add to your Gemfile the `jmespath` gem to use this. jmespath is not a dependency of JSI.",
          "original error message:",
          e.message,
        ].join("\n")
        raise(e.class, msg, e.backtrace)
        # :nocov:
      end
      hashlike = JSI::SchemaSet[].new_jsi({'test' => 0})
      unless JMESPath.search('test', hashlike) == 0
        # :nocov:
        raise(::LoadError, [
          "the loaded version of jmespath cannot be used with JSI.",
          "jmespath is compatible with JSI objects as of version 1.5.0",
        ].join("\n"))
        # :nocov:
      end
      @jmespath_required = true
      nil
    end

    # @param visited_refs [Array<Schema::Ref>]
    # @param ref [Schema::Ref, nil]
    # @return [Array<Schema::Ref>]
    def add_visited_ref(visited_refs, ref)
      return(visited_refs) if ref.nil?
      #chkbug fail unless ref.is_a?(Schema::Ref) && visited_refs.is_a?(Array) && visited_refs.frozen?
      if visited_refs.include?(ref)
        raise(ResolutionError, "cyclical ref application with refs: #{visited_refs}")
      end
      visited_refs.dup.push(ref).freeze
    end

    # Defines equality methods and #hash (for Hash / Set), based on a method #jsi_fingerprint
    # implemented by the includer. #jsi_fingerprint is to include the class and any properties
    # of the instance which constitute its identity.
    module FingerprintHash
      # overrides BasicObject#==
      def ==(other)
        __id__ == other.__id__ || (other.is_a?(FingerprintHash) && jsi_fingerprint == other.jsi_fingerprint)
      end

      alias_method :eql?, :==

      # overrides Kernel#hash
      def hash
        jsi_fingerprint.hash
      end
    end

    module FingerprintHash::Immutable
      include FingerprintHash

      def ==(other)
        return true if __id__ == other.__id__
        return false unless other.is_a?(FingerprintHash)
        # FingerprintHash::Immutable#hash being memoized, comparing that is basically free.
        # not done with FingerprintHash, its #hash can be expensive.
        return false if other.is_a?(FingerprintHash::Immutable) && hash != other.hash
        jsi_fingerprint == other.jsi_fingerprint
      end

      alias_method :eql?, :==

      def hash
        @jsi_fingerprint_hash ||= jsi_fingerprint.hash
      end

      def freeze
        hash
        super
      end
    end
  end
end
