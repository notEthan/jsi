source "https://rubygems.org"

gemspec

gem 'rake'
gem 'gig'

group(:dev) do
  gem 'irb'
  platform(:mri) { gem 'debug', '> 1' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7') }
end

group(:test) do
  gem 'minitest'
  gem 'minitest-around'
  gem 'minitest-reporters'
  gem 'simplecov', '< 0.22'
  gem 'simplecov-lcov'
end

# jsi does not depend on these, but we wish to test integration with them
group(:extdep) do
  gem 'jmespath', '~> 1.5'
  gem 'scorpio', '~> 0.6'
  gem 'spreedly_openapi', github: 'notEthan/spreedly_openapi', tag: 'v0.2.0'
  gem 'activesupport'
end
