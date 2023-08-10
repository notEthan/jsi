require 'bundler'
bundler_groups = [:default, :test]
bundler_groups << :dev unless ENV['CI']
bundler_groups << :extdep if ENV['JSI_TEST_EXTDEP']
Bundler.setup(*bundler_groups)

if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'debug' }
  require 'debug'
  Object.send(:alias_method, :dbg, :debugger)
end
if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'byebug' }
  require 'byebug'
  Object.send(:alias_method, :dbg, :byebug)
end
if !ENV['CI'] && Bundler.load.specs.any? { |spec| spec.name == 'ruby-debug' }
  require 'ruby-debug'
  Object.send(:alias_method, :dbg, :debugger)
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'jsi'

module JSI
  TEST_RESOURCES_PATH = RESOURCES_PATH.join('test')
end

# tests support of things that duck-type #to_hash
class SortOfHash
  def initialize(hash)
    @hash = hash
  end
  def to_hash
    @hash
  end
  include JSI::Util::FingerprintHash
  def jsi_fingerprint
    {class: self.class, hash: @hash}
  end
end

# tests support of things that duck-type #to_ary
class SortOfArray
  def initialize(ary)
    @ary = ary
  end
  def to_ary
    @ary
  end
  include JSI::Util::FingerprintHash
  def jsi_fingerprint
    {class: self.class, ary: @ary}
  end
end

class Module
  def redef_method(method_name, method = nil, &block)
    begin
      remove_method(method_name)
    rescue NameError
    end

    if method
      define_method(method_name, method, &block)
    else
      define_method(method_name, &block)
    end
  end
end
