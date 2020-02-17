lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jsi/version"

Gem::Specification.new do |spec|
  spec.name    = "jsi"
  spec.version = JSI::VERSION
  spec.authors = ["Ethan"]
  spec.email   = ["ethan.jsi@unth.net"]

  spec.summary     = "JSI: JSON Schema Instantiation"
  spec.description = "JSI offers an Object-Oriented representation for JSON data using JSON Schemas"
  spec.homepage    = "https://github.com/notEthan/jsi"
  spec.license     = "AGPL-3.0"

  spec.files = [
    'LICENSE.md',
    'CHANGELOG.md',
    'README.md',
    'readme.rb',
    '.yardopts',
    'Rakefile.rb',
    *Dir['lib/**/*'],
    *Dir['\\{resources\\}/schemas/**/*'],
  ].reject { |f| File.lstat(f).ftype == 'directory' }

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-around"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "scorpio", "~> 0.5"
  spec.add_development_dependency "activesupport"
end
