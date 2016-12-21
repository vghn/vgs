#!/usr/bin/env bash
# GIT Functions

# Returns the branch name
vgs_git_branch(){
  if ! git symbolic-ref --short HEAD 2>/dev/null; then return; fi
}

# Returns the short SHA-1 hash
vgs_git_sha1(){
  if ! git rev-parse --short HEAD 2>/dev/null; then echo '0'; fi
}

# NAME: vgs_git_switch_branch
# DESCRIPTION: Switches a git branch
# USAGE: vgs_git_switch_branch {Branch}
# PARAMETERS:
#   1) The branch name (required)
vgs_git_switch_branch(){
  local branch="${1:-}"
  echo "Checking out branch ${branch}"
  git checkout "$branch"
}

# NAME: vgs_git_merge_branch
# DESCRIPTION: Merges a git branch
# USAGE: vgs_git_merge_branch {Branch} {Message}
# PARAMETERS:
#   1) The branch name (required)
#   2) The message (required)
#   3) Sign the resulting merge commit itself (defaults to false)
vgs_git_merge_branch(){
  local branch message sign
  branch="${1:-}"
  message="${2:-}"
  sign="${3:-false}"

  echo "Merging ${branch}"
  if [[ "$sign" == 'true' ]]; then
    git merge --gpg-sign --no-ff -m "$message" "$branch"
  else
    git merge --no-ff -m "$message" "$branch"
  fi
}

# NAME: vgs_git_tag_release
# DESCRIPTION: Tags a release and pushes it upstream
# USAGE: vgs_git_tag_release {Tag} {Description}
# PARAMETERS:
#   1) The tag name (required)
#   2) The tag description (required)
#   3) Sign the tag using the default GPG key (defaults to false)
vgs_git_tag_release(){
  local tag description sign
  tag="${1:-}"
  description="${2:-}"
  sign="${3:-false}"

  echo "Tagging release ${tag}"
  if [[ "$sign" == 'true' ]]; then
    git tag --sign "$tag" -m "$description"
  else
    git tag --annotate "$tag" -m "$description"
  fi
  echo 'Pushing upstream with tags'
  git push --follow-tags
}

# Prints the most recently created tag for the current branch
vgs_git_tag_get_latest(){
  git describe --abbrev=0 --tags
}

# Make sure we are in the root directory
vgs_git_goto_root(){
  cd "$(git rev-parse --show-cdup)" || return
}
