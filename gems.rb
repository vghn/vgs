source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gem 'vtasks', require: false

gem 'rake', require: false

group :development do
  gem 'github_changelog_generator', require: false
end
