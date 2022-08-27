source "https://rubygems.org"

gemspec

gem 'rake'
gem 'gig'

group(:dev) do
  gem 'irb'
  platform(:mri) { gem 'debug' }
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
  gem 'scorpio', '~> 0.6'
  gem 'spreedly_openapi', github: 'notEthan/spreedly_openapi', tag: 'v0.2.0'
  gem 'activesupport'
end
