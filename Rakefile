# Configure the load path so all dependencies in your Gemfile can be required
require 'bundler/setup'

# VGH Module
module VGH
  # Get version number from git tags
  VERSION = (`git describe --always --tags 2>/dev/null`.chomp || '0.0.0-0-0').freeze
  # Semantic version levels
  LEVELS  = [:major, :minor, :patch].freeze

  # Version module
  module Version
    # Split the version number
    def semantic_hash
      @version_hash ||= begin
        {}.tap do |h|
          h[:major], h[:minor], h[:patch], h[:rev], h[:rev_hash] = VERSION[1..-1].split(/[.-]/)
        end
      end
    end

    # Increment the version number
    def bump(level)
      new_version = semantic_hash.dup
      new_version[level] = new_version[level].to_i + 1
      to_zero = LEVELS[LEVELS.index(level) + 1..LEVELS.size]
      to_zero.each { |z| new_version[z] = 0 }
      new_version
    end
  end # module Version

  # Git module
  module Git
    # Get git short commit hash
    def commit
      `git rev-parse --short HEAD`.strip
    end

    # Get the branch name
    def branch
      return ENV['GIT_BRANCH'] if ENV['GIT_BRANCH']
      return ENV['TRAVIS_BRANCH'] if ENV['TRAVIS_BRANCH']
      return ENV['CIRCLE_BRANCH'] if ENV['CIRCLE_BRANCH']
      `git symbolic-ref HEAD --short 2>/dev/null`.strip
    end

    # Get the URL of the origin remote
    def url
      `git config --get remote.origin.url`.strip
    end

    # Get the CI Status (needs https://hub.github.com/)
    def ci_status(branch = 'master')
      `hub ci-status #{branch}`.strip
    end

    # Check if the repo is clean
    def clean_repo
      # Check if there are uncommitted changes
      unless system 'git diff --quiet HEAD'
        abort('ERROR: Commit your changes first.')
      end

      # Check if there are untracked files
      unless `git ls-files --others --exclude-standard`.to_s.empty?
        abort('ERROR: There are untracked files.')
      end

      true
    end
  end # module Git

  # Config module
  module Config
    # Configure the github_changelog_generator/task
    def changelog(config, release: nil)
      config.bug_labels         = 'Type: Bug'
      config.enhancement_labels = 'Type: Enhancement'
      config.future_release     = "v#{release}" if release
    end
  end # module Config
end # module VGH

# Display version
desc 'Display version'
task :version do
  puts "Current version: #{VGH::VERSION}"
end

# Create a list of contributors from GitHub
desc 'Populate CONTRIBUTORS file'
task :contributors do
  system("git log --format='%aN' | sort -u > CONTRIBUTORS")
end

include VGH::Config
require 'github_changelog_generator/task'
GitHubChangelogGenerator::RakeTask.new(:unreleased) do |config|
  changelog(config)
end

include VGH::Version
include VGH::Git
namespace :release do
  VGH::LEVELS.each do |level|
    desc "Increment #{level} version"
    task level.to_sym do
      new_version = bump(level)
      release = "#{new_version[:major]}.#{new_version[:minor]}.#{new_version[:patch]}"
      release_branch = "release_v#{release.gsub(/[^0-9A-Za-z]/, '_')}"
      initial_branch = branch

      # Check if the repo is clean
      clean_repo

      # Create a new release branch
      sh "git checkout -b #{release_branch}"

      # Generate new changelog
      GitHubChangelogGenerator::RakeTask.new(:latest_release) do |config|
        changelog(config, release: release)
      end
      Rake::Task['latest_release'].invoke

      # Push the new changes
      sh "git commit --gpg-sign --message 'Release v#{release}' CHANGELOG.md"
      sh "git push --set-upstream origin #{release_branch}"

      # Waiting for CI to finish
      puts 'Waiting for CI to finish'
      sleep 5 until ci_status(release_branch) == 'success'

      # Merge release branch
      sh "git checkout #{initial_branch}"
      sh "git merge --gpg-sign --no-ff --message 'Release v#{release}' #{release_branch}"

      # Tag release
      sh "git tag --sign v#{release} --message 'Release v#{release}'"
      sh 'git push --follow-tags'
    end
  end
end

# List all tasks by default
Rake::Task[:default].clear if Rake::Task.task_defined?(:default)
task :default do
  puts `rake -T`
end
