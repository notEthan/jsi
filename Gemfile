source "https://rubygems.org"

gemspec

gem 'irb'
platform(:mri) { gem 'debug' }
gem 'rake'
gem 'gig'
gem 'minitest'
gem 'minitest-around'
gem 'minitest-reporters'
gem 'simplecov', '< 0.22'
gem 'simplecov-lcov'

# jsi does not depend on these, but we wish to test integration with them
group(:extdep) do
  gem 'scorpio', '~> 0.6'
  gem 'spreedly_openapi', github: 'notEthan/spreedly_openapi', tag: 'v0.2.0'
  gem 'activesupport'
end
