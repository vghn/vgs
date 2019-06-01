#!/usr/bin/env bash
# Docker scripts
#
# This script builds, tags and pushes docker images, and notifies MicroBadger about changes.
#
# It creates semantic version style tags from "latest". Each git push will be tagged with the branch name ("master" will become "latest"). Tagged releases (formatted as v1.2.3) will be released as "1.2.3", "1.2" and "1".
#
# An alternative approach on Docker Hub would be to use build rules (however, this triggers multiple builds for each tag, which is inefficient).
#     Type    Name                                  Location    Tag
#     Tag     /^v([0-9]+)\.([0-9]+)\.([0-9]+)$/     /           {\1}.{\2}.{\3}
#     Tag     /^v([0-9]+)\.([0-9]+)\.([0-9]+)$/     /           {\1}.{\2}
#     Tag     /^v([0-9]+)\.([0-9]+)\.([0-9]+)$/     /           {\1}
#
# Sample MicroBadger URL
#    export MICROBADGER_URL="https://hooks.microbadger.com/images/myuser/myrepo/ABCDEF="
#
# Sample MicroBadger Tokens file (MICROBADGER_TOKENS_FILE). When exporting a variable containing an array, child processes cannot see the array.  There isn't really a good way to encode an array variable into the environment.
#     declare -A MICROBADGER_TOKENS=(
#       ['myuser/myrepo']='ABCDEF='
#     )
#     export MICROBADGER_TOKENS
#
# Links:
#   - https://docs.docker.com/docker-cloud/builds/advanced/

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# DEBUG
[ -z "${DEBUG:-}" ] || set -x

# Load VGS library
# shellcheck disable=1090
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/load"

# VARs
GIT_TAG="$(git describe --always --tags)"
DOCKER_NO_CACHE="${DOCKER_NO_CACHE:-false}"
DOCKER_BUILD_PATH="${DOCKER_BUILD_PATH:-$(pwd)}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-}"
DOCKER_REPO="${DOCKER_REPO:-}"
DOCKER_TAG="${DOCKER_TAG:-latest}"
DOCKER_IMAGE_NAME="${IMAGE_NAME:-${DOCKER_REPO}:${DOCKER_TAG}}"
MICROBADGER_TOKENS_FILE="${MICROBADGER_TOKENS_FILE:-.microbadger}"
MICROBADGER_URL="${MICROBADGER_URL:-}"

# Usage
usage(){
  echo '---------------------------------------------'
  echo "USAGE: ${BASH_SOURCE[0]} [COMMAND]"
  echo '---------------------------------------------'
  echo 'Commands:'
  echo ''
  echo '  - build'
  echo '    Builds image'
  echo ''
  echo '  - push'
  echo '    Pushes the "latest" tag'
  echo ''
  echo '  - tag'
  echo '    Tags and pushes the image with semantic version'
  echo ''
  echo '  - notify'
  echo '    Notifies MicroBadger'
  echo ''
  echo '  - test'
  echo '    Tests image'
  echo ''
  echo '----------------------------------------------'
  exit 1
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

  export major="${semver[0]}"
  export minor="${semver[1]}"
  export patch="${semver[2]}"
}

# Deepen repository history
# When Docker Cloud pulls a branch from a source code repository, it performs a shallow clone (only the tip of the specified branch). This has the advantage of minimizing the amount of data transfer necessary from the repository and speeding up the build because it pulls only the minimal code necessary.
# Because of this, if you need to perform a custom action that relies on a different branch (such as a post_push hook), you won’t be able checkout that branch, unless you do one of the following:
#    $ git pull --depth=50
#    $ git fetch --unshallow origin
deepen_git_repo(){
  if [[ -f $(git rev-parse --git-dir)/shallow ]]; then
    echo 'Deepen repository history'
    git fetch --unshallow origin
  fi
}

# Build
build_image(){
  deepen_git_repo

  # Pull image before build to speed up the building process
  if [[ "$DOCKER_NO_CACHE" == 'false' ]]; then
    echo 'Pulling image'
    docker pull "${DOCKER_REPO}:latest"
  fi

  echo 'Build the image with the specified arguments'
  (
    cd "${DOCKER_BUILD_PATH}"
    docker build \
      --build-arg VERSION="$GIT_TAG" \
      --build-arg VCS_URL="$(git config --get remote.origin.url)" \
      --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
      --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --file "$DOCKERFILE_PATH" \
      --tag "$DOCKER_IMAGE_NAME" \
      .
  )
}

# Push
push_image(){
  echo "Pushing ${DOCKER_IMAGE_NAME}"
  docker push "${DOCKER_IMAGE_NAME}"
}

# Tag
tag_image(){
  generate_semantic_version

  for version in "${major}.${minor}.${patch}" "${major}.${minor}" "${major}"; do
    echo "Pushing version (${DOCKER_REPO}:${version})"
    docker tag "$DOCKER_IMAGE_NAME" "${DOCKER_REPO}:${version}"
    docker push "${DOCKER_REPO}:${version}"
  done
}

# Notify Microbadger
notify_microbadger(){
  # shellcheck disable=1090
  if [[ -s "$MICROBADGER_TOKENS_FILE" ]]; then . "$MICROBADGER_TOKENS_FILE"; fi

  # Remove Docker Hub prefix (if it exists)
  DOCKER_REPO="${DOCKER_REPO#index.docker.io/}"

  if [[ -n "$DOCKER_REPO" ]] && [[ "$(declare -p MICROBADGER_TOKENS 2>/dev/null)" =~ "declare -A" ]]; then
    echo "Found MICROBADGER_TOKENS array in ${MICROBADGER_TOKENS_FILE}"
    local token
    token="${MICROBADGER_TOKENS[${DOCKER_REPO}]:-}"
    if [[ -n "$token" ]]; then
      echo "Using MicroBadger Token for ${DOCKER_REPO}"
      MICROBADGER_URL="https://hooks.microbadger.com/images/${DOCKER_REPO}/${token}"
    else
      echo "No MicroBadger Token found for ${DOCKER_REPO}"
    fi
  fi

  if [[ -n "${MICROBADGER_URL:-}" ]]; then
    echo "Notify MicroBadger: $(curl -sX POST "$MICROBADGER_URL")"
  fi
}

# Logic
main(){
  export cmd="${1:-}"; shift || true
  case "$cmd" in
    build)
      build_image
      ;;
    push)
      push_image
      ;;
    tag)
      tag_image
      ;;
    notify)
      notify_microbadger
      ;;
    *)
      usage
      ;;
  esac
}

# Run
main "${@:-}"
