source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gem 'rake', require: false

group :development do
  gem 'github_changelog_generator', require: false
end
