#!/usr/bin/env bash
# GIT Functions

# Returns the branch name
vgs_git_branch(){
  git symbolic-ref --short HEAD 2>/dev/null
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
vgs_git_merge_branch(){
  local branch message
  branch="${1:-}"
  message="${2:-}"

  echo "Merging ${branch}"
  git merge --no-ff -m "$message" "$branch"
}

# NAME: vgs_git_tag_release
# DESCRIPTION: Tags a release and pushes it upstream
# USAGE: vgs_git_tag_release {Tag} {Description}
# PARAMETERS:
#   1) The tag name (required)
#   2) The tag description (required)
vgs_git_tag_release(){
  local tag description
  tag="${1:-}"
  description="${2:-}"

  echo "Tagging release ${tag}"
  git tag -a "$tag" -m "$description"
  echo 'Pushing upstream with tags'
  git push --follow-tags
}

# Make sure we are in the root directory
vgs_git_goto_root(){
  cd "$(git rev-parse --show-cdup)" || return
}
