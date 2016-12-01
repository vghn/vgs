def version
  `git describe --always --tags`.strip
end

def version_hash
  @version_hash ||= begin
    v = version
    {}.tap do |h|
      h[:major], h[:minor], h[:patch], h[:rev], h[:rev_hash] = v[1..-1].split(/[.-]/)
    end
  end
end

def increment_version(level)
  v = version_hash.dup
  v[level] = v[level].to_i + 1

  to_zero = LEVELS[LEVELS.index(level) + 1..LEVELS.size]
  to_zero.each { |z| v[z] = 0 }

  v
end

def configure_changelog(config, release: nil)
  config.bug_labels         = 'Type: Bug'
  config.enhancement_labels = 'Type: Enhancement'
  config.future_release     = "v#{release}" if release
end

# GitHub CHANGELOG generator
require 'github_changelog_generator/task'
GitHubChangelogGenerator::RakeTask.new(:unreleased) do |config|
  configure_changelog(config)
end

namespace :release do
  LEVELS = [:major, :minor, :patch].freeze
  LEVELS.each do |level|
    desc "Increment #{level} version"
    task level.to_sym do
      v       = increment_version(level)
      release = "#{v[:major]}.#{v[:minor]}.#{v[:patch]}"

      sh "git checkout -b bump_v#{release}"
      GitHubChangelogGenerator::RakeTask.new(:latest_release) do |config|
        configure_changelog(config, release: release)
      end
      Rake::Task['latest_release'].invoke

      sh "git commit --gpg-sign --message 'Release v#{release}' CHANGELOG.md"
      sh "git tag --sign v#{release} --message 'Release v#{release}'"
      sh 'git push --follow-tags'
    end
  end
end

# List all tasks by default
task :default do
  puts `rake -T`
end

# Version
desc 'Display version'
task :version do
  puts "Current version: #{version}"
end
