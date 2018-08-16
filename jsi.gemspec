lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jsi/version"

Gem::Specification.new do |spec|
  spec.name          = "jsi"
  spec.version       = JSI::VERSION
  spec.authors       = ["Ethan"]
  spec.email         = ["ethan@unth"]

  spec.summary       = "JSI: JSON-Schema instantiation"
  spec.description   = "JSI represents json-schemas as ruby classes and json-schema instances as instances of those classes"
  spec.homepage      = "https://github.com/notEthan/jsi"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w(.gitignore .travis.yml Gemfile test)
  ignore_files_re = %r{\A(#{ignore_files.map { |f| Regexp.escape(f) }.join('|')})(/|\z)}
  Dir.chdir(File.expand_path('..', __FILE__)) do
    spec.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(ignore_files_re) }
    spec.test_files  = `git ls-files -z test`.split("\x0")
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
