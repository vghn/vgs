#!/usr/bin/env bash
# Semantic Release
#
# This script generates a changelog based on tagged issues or pull requests and creates semantic version tags and releases.
#
# It has the following dependencies:
# - GitHub Changelog Generator (https://github.com/github-changelog-generator/github-changelog-generator)
# - GitHub Hub (https://github.com/github/hub)
# - Git
# - Docker
#
# USAGE:
# $ ./scripts/release.sh patch
#
# NOTE:
# First time you have to create an annotated tag and commit the initial CHANGELOG, before creating issues or pull requests (if there these are not present it will fail)
# $ git tag --sign v0.0.0 --message 'Release v0.0.0' && git push --follow-tags

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# DEBUG
[[ -z "${DEBUG:-}" ]] || set -x

# VARs
## [STRING] GitHub user name
GIT_REPO_OWNER="${GIT_REPO_OWNER:-$(basename "$(dirname "$(git remote get-url origin)")")}"
## [STRING] GitHub repository name
GIT_REPO="${GIT_REPO:-$(basename -s .git "$(git remote get-url origin)")}"
## [STRING] GitHub Authentication Token (GitHub only allows 50 unauthenticated
## requests per hour). You can generate a token at https://github.com/settings/tokens/new?description=GitHub%20Changelog%20Generator%20token
## You only need "repo" scope for private repositories
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
## [Boolean] Whether to write the changelog (defaults to `true`)
## If `false` it will just created a git semantic versioned git tag
WRITE_CHANGELOG="${WRITE_CHANGELOG:-true}"
## [Boolean] In case the branch is protected and a pull request is required,
## the task will create a separate branch on which it will commit the changelog,
## and merge that into master (defaults to `false`)
REQUIRE_PULL_REQUEST="${REQUIRE_PULL_REQUEST:-false}"
## [Boolean] Whether a "SUCCESS" CI status is required (defaults to `false`)
## requires GitHub Hub - https://github.com/github/hub)
WAIT_FOR_CI_SUCCESS="${WAIT_FOR_CI_SUCCESS:-false}"
## [Boolean] Whether to create a GitHub release (defaults to `true`)
## requires GitHub Hub - https://github.com/github/hub)
PUBLISH_RELEASE="${PUBLISH_RELEASE:-true}"

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
  echo 'For the environment variables used to configure this script,'
  echo ' check the comments in the VARs section'
  echo ''
  echo '----------------------------------------------'
}

# Make sure things exists
sanity_checks(){
  if ! command -v git >/dev/null 2>&1; then echo 'ERROR: Git is not installed!'; exit 1; fi
  if ! command -v hub >/dev/null 2>&1; then echo 'ERROR: GitHub Hub is not installed!'; exit 1; fi
  if ! git diff --quiet HEAD; then echo 'ERROR: Commit your changes first'; exit 1; fi
  if ! ( command -v github_changelog_generator >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 ); then
    echo 'ERROR: The github_changelog_generator gem or docker is not installed!'; exit 1
  fi
}

# Get semantic version from git tags (tag needs to be in the v1.2.3 format)
get_semantic_version(){
  GIT_TAG="$(git describe --always --tags)"

  # If tag matches semantic version
  if [[ "$GIT_TAG" != v* ]]; then
    echo "Version (${GIT_TAG}) does not match semantic version; Skipping..."
    return 1
  fi

  # Break the version into components
  semver="${GIT_TAG#v}" # Remove the 'v' prefix
  semver="${semver%%-*}" # Remove the commit number
  IFS="." read -r -a semver <<< "$semver" # Create an array with version numbers

  MAJOR="${semver[0]}"
  MINOR="${semver[1]}"
  PATCH="${semver[2]}"
}

# Generate changelog
generate_changelog(){
  eval "docker run -it --rm -e CHANGELOG_GITHUB_TOKEN=${GITHUB_TOKEN} -v $(pwd):/usr/local/src/your-app ferrarimarco/github-changelog-generator --user ${GIT_REPO_OWNER} --project ${GIT_REPO}" "${@:-}"
}

# Logic
main(){
  sanity_checks
  get_semantic_version

  # Process arguments
  case "${1:-}" in
    major)
      MAJOR=$((MAJOR+1)) MINOR=0 PATCH=0
      shift
      ;;
    minor)
      MINOR=$((MINOR+1)) PATCH=0
      shift
      ;;
    patch)
      PATCH=$((PATCH+1))
      shift
      ;;
    unreleased)
      generate_changelog --unreleased
      return
      ;;
    *)
      usage; return
      ;;
  esac

  # Compose release
  RELEASE="v${MAJOR}.${MINOR}.${PATCH}"

  # Detect branch names
  INITIAL_BRANCH="${GIT_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null)}"
  if [[ "$REQUIRE_PULL_REQUEST" == 'true' ]]; then
    RELEASE_BRANCH="release_${RELEASE//./_}"
  else
    RELEASE_BRANCH="$INITIAL_BRANCH"
  fi

  if [[ "$REQUIRE_PULL_REQUEST" == 'true' ]]; then
    echo 'Create a new release branch'
    git checkout -b "$RELEASE_BRANCH"
  fi

  if [[ "$WRITE_CHANGELOG" == 'true' ]]; then
    generate_changelog --future-release ${RELEASE:-}

    if ! git diff --quiet HEAD; then
      echo 'Commit CHANGELOG'
      git add CHANGELOG.md
      git commit --gpg-sign --message "Update change log for ${RELEASE}" CHANGELOG.md
    fi
  fi

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

  echo "Tag  ${RELEASE}"
  git tag --sign "${RELEASE}" --message "Release ${RELEASE}"
  git push --follow-tags

  if [[ "$PUBLISH_RELEASE" == 'true' ]]; then
    echo 'Publish release'
      cat<<EOF | hub release create -F - "$RELEASE"
Release ${RELEASE}

$(awk -v version="[${RELEASE}](https://github.com/${GIT_REPO_OWNER}/${GIT_REPO}/tree/${RELEASE})" '/## / {printit = $2 == version}; printit;' CHANGELOG.md)
EOF
    # This can also be used but the disadvantage is that it will scan and recreate the CHANGELOG again, plus the output file will be owned by root if the command is used inside the docker container:
    # generate_changelog --header-label "Release_${RELEASE}" --unreleased-only --future-release "$RELEASE" --output release_notes.md
    # hub release create -F release_notes.md "$RELEASE"
  fi
}

# Run
main "${@:-}"
