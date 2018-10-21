# Configure the load path so all dependencies in your Gemfile can be required
require 'bundler/setup'

# Create a list of contributors from GitHub
desc 'Generate a Change log from GitHub'
task release: ['release:changes']

namespace :release do
  require 'github_changelog_generator'

  desc 'Generate a Change log from GitHub'
  task :changes do
    system "BUG_LABELS='Type: Bug' ENHANCEMENT_LABELS='Type: Enhancement' ./scripts/release.sh unreleased"
  end

  ['patch', 'minor', 'major'].each do |level|
    desc "Release #{level} version"
    task level.to_sym do
      system "WRITE_CHANGELOG=true BUG_LABELS='Type: Bug' ENHANCEMENT_LABELS='Type: Enhancement' ./scripts/release.sh #{level}"
    end
  end
end

# Display version
desc 'Display version'
task :version do
  system "git describe --always --tags 2>/dev/null || echo '0.0.0-0-0'"
end

# Create a list of contributors from GitHub
desc 'Populate CONTRIBUTORS file'
task :contributors do
  system "git log --format='%aN' | sort -u > CONTRIBUTORS"
end

# List all tasks by default
Rake::Task[:default].clear if Rake::Task.task_defined?(:default)
task :default do
  system 'rake -T'
end
