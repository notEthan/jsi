lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jsi/version"

Gem::Specification.new do |spec|
  spec.name    = "jsi"
  spec.version = JSI::VERSION
  spec.authors = ["Ethan"]
  spec.email   = ["ethan@unth.net"]

  spec.summary     = "JSI: JSON Schema Instantiation"
  spec.description = "JSI offers an Object-Oriented representation for JSON data using JSON Schemas"
  spec.homepage    = "https://github.com/notEthan/jsi"
  spec.license     = "AGPL-3.0"
  ignore_files = %w(.gitignore .travis.yml Gemfile test)
  ignore_files_re = %r{\A(#{ignore_files.map { |f| Regexp.escape(f) }.join('|')})(/|\z)}
  Dir.chdir(File.expand_path('..', __FILE__)) do
    spec.files      = `git ls-files -z`.split("\x0").reject { |f| f.match(ignore_files_re) }
    spec.test_files = `git ls-files -z test`.split("\x0")
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # we are monkey patching json-schema with a fix that has not been merged in a timely fashion.
  spec.add_dependency "json-schema", "~> 2.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-around"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "scorpio"
end
