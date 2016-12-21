require 'yaml'

# Global Variables
CFG_FILE = "#{ENV['HOME']}/.projects.yaml" # Configuration file

# Load configuration
class CONFIG
  def self.read
    YAML.load_file(CFG_FILE) if File.exist? CFG_FILE
  end
end

# Configure the github_changelog_generator/task
def configure_changelog(config, release: nil)
  config.bug_labels         = 'Type: Bug'
  config.enhancement_labels = 'Type: Enhancement'
  config.future_release     = "v#{release}" if release
end
