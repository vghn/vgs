#!/usr/bin/env bash
# Semantic Release scripts
#
# This script generates a changelog based on tagged issues or pull requests and creates semantic version tags.
# It uses the GitHub Changelog Generator gem (https://github.com/github-changelog-generator/github-changelog-generator):
# $ [sudo] gem install github_changelog_generator
#
# Environment Variables:
#   - `CHANGELOG_GITHUB_TOKEN`: [STRING] GitHub Authentication Token (GitHub only allows 50 unauthenticated requests per hour). You can generate a token at https://github.com/settings/tokens/new?description=GitHub%20Changelog%20Generator%20token (you only need "repo" scope for private repositories)
#   - `WRITE_CHANGELOG`: [Boolean] whether to write the changelog (defaults to `false`)
#   - `REQUIRE_PULL_REQUEST`: [Boolean] in case the branch is protected and a pull request is required, the task will create a separate branch on #   which it will commit the changelog, and merge that into master (defaults to `false`).
#   - `WAIT_FOR_CI_SUCCESS`: [Boolean] whether a "SUCCESS" CI status is required (defaults to `false`)
#   - `BUG_LABELS`: [STRING] Issues with the specified labels will be added to "Fixed bugs" section (defaults to `bug`)
#   - `ENHANCEMENT_LABELS`: [STRING] Issues with the specified labels will be added to "Implemented enhancements" section (defaults to `enhancement`)
#
# USAGE:
# $ WRITE_CHANGELOG=true BUG_LABELS='Type: Bug' ENHANCEMENT_LABELS='Type: Enhancement' ~/vgs/scripts/release.sh patch
#
# NOTE:
# First time you have to create an annotated tag and commit the initial CHANGELOG, before creating issues or pull requests (if there these are not present it will fail)
# $ git tag --sign v0.0.0 --message 'Release v0.0.0' && git push --follow-tags
#
# RAKE TASKS:
# desc 'Generate a Change log from GitHub'
# task release: ['release:changes']
# namespace :release do
#   require 'github_changelog_generator'
#   desc 'Generate a Change log from GitHub'
#   task :changes do
#     system "BUG_LABELS='Type: Bug' ENHANCEMENT_LABELS='Type: Enhancement' ~/vgs/scripts/release.sh unreleased"
#   end
#   ['patch', 'minor', 'major'].each do |level|
#     desc "Release #{level} version"
#     task level.to_sym do
#       system "WRITE_CHANGELOG=true BUG_LABELS='Type: Bug' ENHANCEMENT_LABELS='Type: Enhancement' ~/vgs/scripts/release.sh #{level}"
#     end
#   end
# end
# desc 'Display version'
# task :version do
#   system "git describe --always --tags 2>/dev/null || echo '0.0.0-0-0'"
# end

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# DEBUG
[[ -z "${DEBUG:-}" ]] || set -x

# Load VGS library
# shellcheck disable=1090
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/load"

# VARs
BUG_LABELS="${BUG_LABELS:-bug}"
CHANGELOG_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ENHANCEMENT_LABELS="${ENHANCEMENT_LABELS:-enhancement}"
GIT_TAG="$(git describe --always --tags)"
REQUIRE_PULL_REQUEST="${REQUIRE_PULL_REQUEST:-false}"
WAIT_FOR_CI_SUCCESS="${WAIT_FOR_CI_SUCCESS:-false}"
WRITE_CHANGELOG="${WRITE_CHANGELOG:-false}"
export BUG_LABELS CHANGELOG_GITHUB_TOKEN ENHANCEMENT_LABELS GIT_TAG \
  REQUIRE_PULL_REQUEST WAIT_FOR_CI_SUCCESS WRITE_CHANGELOG

# Usage
usage(){
  echo '---------------------------------------------'
  echo "USAGE: ${BASH_SOURCE[0]} [COMMAND]"
  echo '---------------------------------------------'
  echo 'Commands:'
  echo ''
  echo '  - major'
  echo '    Increments the Major version'
  echo ''
  echo '  - minor'
  echo '    Increments the Minor version'
  echo ''
  echo '  - patch'
  echo '    Increments the Patch version'
  echo ''
  echo '  - unreleased'
  echo '    Adds unreleased changes to the CHANGELOG'
  echo ''
  echo '----------------------------------------------'
  exit 1
}

# Check if the repository is clean
git_clean_repo(){
  git diff --quiet HEAD || (
    echo 'ERROR: Commit your changes first'
    return 1
  )
}

# Generate semantic version style tags
generate_semantic_version(){
  # If tag matches semantic version
  if [[ "$GIT_TAG" != v* ]]; then
    echo "Version (${GIT_TAG}) does not match semantic version; Skipping..."
    return
  fi

  # Break the version into components
  semver="${GIT_TAG#v}" # Remove the 'v' prefix
  semver="${semver%%-*}" # Remove the commit number
  IFS="." read -r -a semver <<< "$semver" # Create an array with version numbers

  export MAJOR="${semver[0]}"
  export MINOR="${semver[1]}"
  export PATCH="${semver[2]}"
}

# Increment Semantic Version
increment(){
  generate_semantic_version

  case "${1:-patch}" in
    major)
      export MAJOR=$((MAJOR+1))
      export MINOR=0
      export PATCH=0
      ;;
    minor)
      export MINOR=$((MINOR+1))
      export PATCH=0
      ;;
    patch)
      export PATCH=$((PATCH+1))
      ;;
    *)
      export PATCH=$((PATCH+1))
      ;;
  esac
}

# Generate log
generate_log(){
  GCG_CMD="--bug-labels '${BUG_LABELS}' --enhancement-labels '${ENHANCEMENT_LABELS}'"

  if command -v github_changelog_generator >/dev/null 2>&1; then
    # If release is empty is the same as `unreleased`
    eval "github_changelog_generator $GCG_CMD --future-release ${RELEASE:-}"
  else
    echo 'ERROR: github_changelog_generator is not installed!'
    exit 1
  fi
}

# logic
main(){
  case "${1:-}" in
    major)
      increment major
      ;;
    minor)
      increment minor
      ;;
    patch)
      increment patch
      ;;
    unreleased)
      generate_log; exit 0
      ;;
    *)
      usage
      ;;
  esac

  if ! command -v git >/dev/null 2>&1; then echo 'ERROR: Git is not installed!'; exit 1; fi

  git_clean_repo

  RELEASE="v${MAJOR}.${MINOR}.${PATCH}"

  # Detect branch names
  INITIAL_BRANCH="${GIT_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null)}"
  if [[ "$REQUIRE_PULL_REQUEST" == 'true' ]]; then
    RELEASE_BRANCH="release_${RELEASE//./_}"
  else
    RELEASE_BRANCH="$INITIAL_BRANCH"
  fi

  if [[ "$WRITE_CHANGELOG" == 'true' ]]; then
    generate_log

    git diff --quiet HEAD || (

      if [[ "$REQUIRE_PULL_REQUEST" == 'true' ]]; then
        echo 'Create a new release branch'
        git checkout -b "$RELEASE_BRANCH"
      fi

      echo 'Commit CHANGELOG'
      git add CHANGELOG.md
      git commit --gpg-sign --message "Update change log for ${RELEASE}" CHANGELOG.md

      if [[ "$WAIT_FOR_CI_SUCCESS" == 'true' ]]; then
        echo 'Waiting for CI to finish'
        while [[ $(hub ci-status "$RELEASE_BRANCH") != "success" ]]; do
          sleep 5
        done
      fi

      if [[ "$REQUIRE_PULL_REQUEST" == 'true' ]]; then
        echo 'Merge release branch'
        git checkout "$INITIAL_BRANCH"
        git merge --gpg-sign --no-ff --message "Release ${RELEASE}" "$RELEASE_BRANCH"
      fi
    )
  fi

  echo "Tag  ${RELEASE}"
  git tag --sign "${RELEASE}" --message "Release ${RELEASE}"
  git push --follow-tags
}

# Run
main "${@:-}"
