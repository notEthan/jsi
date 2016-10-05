# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scorpio/version'

Gem::Specification.new do |spec|
  spec.name          = "scorpio"
  spec.version       = Scorpio::VERSION
  spec.authors       = ["Ethan"]
  spec.email         = ["ethan@unth"]

  spec.summary       = 'Scorpio REST client'
  spec.description   = 'ORM style REST client'
  spec.homepage      = "https://github.com/notEthan/scorpio"
  spec.license       = "MIT"
  ignore_files = %w(.gitignore .travis.yml Gemfile test)
  ignore_files_re = %r{\A(#{ignore_files.map { |f| Regexp.escape(f) }.join('|')})(/|\z)}
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(ignore_files_re) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday"
  spec.add_dependency "faraday_middleware"
  spec.add_dependency "json-schema"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-around"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "sinatra", "~> 1.0"
  spec.add_development_dependency "rack", "~> 1.0"
  spec.add_development_dependency "rack-accept"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "api_hammer"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "simplecov"
end
