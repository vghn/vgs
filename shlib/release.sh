#!/usr/bin/env bash
# Release functions

# DESCRIPTION: Get previous version
# REQUIRES:
#   - $version_file : the version file
vgs_release_get_range(){
  local previous; previous=$(cat "$version_file")
  if [[ "$previous" == '0.0.0' ]]; then
    echo "$git_branch"
  elif ! git show-ref --quiet --verify "refs/tags/${previous}"; then
    echo "${release_branch}...${git_branch}"
  else
    echo "$previous"
  fi
}

# DESCRIPTION: Sanity Checks
# REQUIRES:
#   - $release : the release type
#   - $version_file : the version file
#   - $changelog_file : the changelog file
#   - $git_branch : the curent git branch
vgs_release_sanity_checks(){
  # Check if the type is correct
  case "$release" in
    major|minor|patch)
      # Check if there are uncommitted changes
      git diff --quiet HEAD || e_abort 'ERROR: There are uncommitted changes!'
      # Check if there are untracked files
      [[ -z $(git ls-files --others --exclude-standard ) ]] || \
        e_abort 'ERROR: There are untracked files!'
      # Check if the version file exists (create otherwise)
      [[ -s "$version_file" ]] || echo '0.0.0' > "$version_file"
      # Check if the changelog file exists (create otherwise)
      [[ -f "$changelog_file" ]] || touch "$changelog_file"
      # Check if there are changes between the branches
      [[ -n $(git log "$(vgs_release_get_range)" --no-merges) ]] || \
        e_abort 'ERROR: No changes were detected'
      ;;
    *)
      e_abort 'ERROR: The release type needs to be one of: major, minor, patch!'
      ;;
  esac
}

# DESCRIPTION: List changes from git log, excluding those starting with 'Minor' or 'WIP'
# REQUIRES:
#   - $git_branch : the curent git branch
#   - $github_url : the url for the GitHub repository
vgs_release_get_changes(){
  git log "$(vgs_release_get_range)" --reverse --no-merges \
    --grep '^Submodules update$' --grep '^WIP' --grep '^Bump.*version.*' \
    --invert-grep --pretty=format:"  * %s ([%cn - %h](${github_url}/commit/%H))"
}

# NAME: vgs_release_write_version_to_file
# DESCRIPTION: Increments version number in file
# USAGE: vgs_release_write_version_to_file {Version}
# REQUIRES:
#   - $version_file : the version file
# PARAMETERS:
#   1) The new version (required)
vgs_release_write_version_to_file(){
  echo 'Writing the new version'
  echo "$1" > "$version_file"
}

# NAME: vgs_release_write_changes_to_file
# DESCRIPTION: Appends changes to the beginning of the change log
# USAGE: vgs_release_write_changes_to_file {Version} {Changes}
# REQUIRES:
#   - $changelog_file : the changelog file
# PARAMETERS:
#   1) The new version (required)
#   2) The changes (required)
vgs_release_write_changes_to_file(){
  echo 'Writing the new changelog'
  echo -e "## Version ${1} / $(date +%Y-%m-%d)\\n${2}\\n\\n$(cat "$changelog_file")" > "${changelog_file}.new"
  mv "${changelog_file}.new" "$changelog_file"
}

# Increment patch version
# REQUIRES:
#   - $version_file : the version file
vgs_release_version_increment_patch(){ awk -F'[.]' '{print $1"."$2"."$3+1}' "$version_file" ;}

# Increment minor version and reset patch
# REQUIRES:
#   - $version_file : the version file
vgs_release_version_increment_minor(){ awk -F'[.]' '{print $1"."$2+1".0"}' "$version_file" ;}

# Increment major version and reset minor and patch
# REQUIRES:
#   - $version_file : the version file
vgs_release_version_increment_major(){ awk -F'[.]' '{print $1+1".0.0"}' "$version_file" ;}

# NAME: vgs_release_commit_changes
# DESCRIPTION: Commits the changes to version file and changelog
# USAGE: vgs_release_commit_changes {Type} {Version}
# REQUIRES:
#   - $version_file : the version file
#   - $changelog_file : the changelog file
# PARAMETERS:
#   1) The type of change (required)
#   2) The new version (required)
vgs_release_commit_changes(){
  local commit_message="Bump ${1} version to v${2}"

  echo "Committing version and changelog files ($1 version $2)"
  git add "$version_file" "$changelog_file"
  if [[ "$sign_commit" == 'true' ]]; then
    git commit --gpg-sign -m "$commit_message"
  else
    git commit -m "$commit_message"
  fi
}

# NAME: vgs_release_push_changes
# DESCRIPTION: Pushes the current branch upstream
# USAGE: vgs_release_push_changes
# REQUIRES:
#   - $git_branch : the branch name
vgs_release_push_changes(){
  # Disable ENVTYPE cli overriding (it should be auto detected only, otherwise
  # it will persist between pushes)
  unset ENVTYPE
  git push --set-upstream origin "$git_branch"
}

# Merges a git branch
vgs_release_wait_for_ci(){
  echo 'Waiting for CI to finish'
  until [[ $(hub ci-status) == 'success' ]]; do sleep 5; done
}

# Release logic
vgs_release_main(){
  # the current branch
  git_branch=$(vgs_git_branch)
  vgs_git_goto_root
  vgs_release_sanity_checks

  local new_version changes
  new_version=$(vgs_release_version_increment_"${release}")
  changes=$(vgs_release_get_changes)

  vgs_release_write_version_to_file "$new_version"
  vgs_release_write_changes_to_file "$new_version" "$changes"
  echo 'Take a minute to review the change log'
  echo 'Press any key to continue or "CTRL+C" to exit'
  read -r -n1 -s
  vgs_release_commit_changes "$release" "$new_version"
  vgs_release_push_changes
  vgs_release_wait_for_ci

  vgs_git_switch_branch "$release_branch"
  vgs_git_merge_branch "$git_branch" "Release v${new_version}" "$sign_commit"
  vgs_git_tag_release "v${new_version}" "Version ${new_version} / $(date +%Y-%m-%d)" "$sign_commit"

  vgs_git_switch_branch "$git_branch"
  git rebase "$release_branch"
}

# Usage
vgs_release_usage(){
  read -r -d '' usage <<-'EOF' || true # exits non-zero when EOF encountered
  -t --type [arg]             Release type. One of: patch, minor or major.
                              Default: 'patch'
  -b --release-branch [arg]   The branch to release from. Default: 'master'
  -c ----changelog-file [arg] The path to the changelog file
                              Default: 'CHANGELOG.md'
  -f --version-file [arg]     The path to the version file
                              Default: 'VERSION'
  -u --github-url [arg]       The URL of the GitHub repository
  -s --sign                   Sign the merge commit and tags
  -h --help                   Usage
EOF
  echo "$usage"
}

# WORKFLOW:
#   - Create a new feature branch
#   - Commit your work and push it upstream
#   - Create a Pull Request on GitHub and review changes (Optional)
#   - run `bin/release {TYPE}` ( Where TYPE is the semantic version type: major,
#     minor or patch; defaults to patch)
#
# This script will:
#   - Verify that: the arguments are correct, there are no uncommitted changes
#     or untracked files, the files exist and there are actually changes present
#   - Increment the version number and update the VERSION file
#   - Compile a list of commit messages since the latest tag and update the
#     CHANGELOG file
#   - Create a 'Bump version' commit and push it upstream
#   - Wait for the CI to finish testing the current branch
#   - Switch to the release branch and merge the feature branch
#   - Tag the release
#   - Switch back to the feature branch and rebase it from the release branch
vgs_release(){
  # Defaults
  release='patch'
  release_branch='master'
  changelog_file='CHANGELOG.md'
  version_file='VERSION'
  github_url=''
  sign_commit=false

  # Process arguments
  while :
  do
    case "${1:-}" in
      -t | --type)
        release="${2:-patch}"
        shift 2
        ;;
      -b | --release-branch)
        release_branch="$2"
        shift 2
        ;;
      -c | --changelog-file)
        changelog_file="${2:-CHANGELOG.md}"
        shift 2
        ;;
      -f | --version-file)
        version_file="${2:-VERSION}"
        shift 2
        ;;
      -u | --github-url)
        github_url="$2"
        shift 2
        ;;
      -s | --sign)
        sign_commit=true
        shift
        ;;
      -h | --help)
        vgs_release_usage; return 0
        ;;
      --) # End of all options
        shift
        break
        ;;
      -*)
        e_abort "Error: Unknown option: ${1}"; return 1
        ;;
      *)  # No more options
        break
        ;;
    esac
  done

  # Run release logic
  vgs_release_main
}
