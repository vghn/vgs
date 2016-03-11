#!/usr/bin/env bash
# Release functions

# DESCRIPTION: Get previous version
# REQUIRES:
#   - $version_file : the version file
vgs_release_get_last_tag(){
  local previous; previous=$(cat "$version_file")
  if [[ "$previous" == '0.0.0' ]]; then echo 'master'; else echo "$previous"; fi
}

# DESCRIPTION: Sanity Checks
# REQUIRES:
#   - $version_file : the version file
#   - $changelog_file : the changelog file
#   - $git_branch : the curent git branch
vgs_release_sanity_checks(){
  # Check if there are uncommitted changes
  git diff --quiet HEAD || e_abort 'ERROR: There are uncommitted changes!'
  # Check if there are untracked files
  [[ -z $(git ls-files --others --exclude-standard ) ]] || \
    e_abort 'ERROR: There are untracked files!'
  # Check if the version file exists
  [[ -s "$version_file" ]] || \
    e_abort 'ERROR: Could not find the VERSION file!'
  # Check if the changelog file exists
  [[ -f "$changelog_file" ]] || \
    e_abort 'ERROR: Could not find the CHANGELOG file!'
  # Check if there are changes between the branches
  [[ -n $(git log "$(vgs_release_get_last_tag)"..."$git_branch" --no-merges) ]] || \
    e_abort 'ERROR: No changes were detected'
}

# DESCRIPTION: List changes from git log, excluding those starting with 'Minor' or 'WIP'
# REQUIRES:
#   - $git_branch : the curent git branch
#   - $github_url : the url for the GitHub repository
vgs_release_get_changes(){
  git log "$(vgs_release_get_last_tag)"..."$git_branch" --reverse --no-merges \
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
  echo -e "## Version ${1} / $(date +%Y-%m-%d)\n${2}\n\n$(cat "$changelog_file")" > "${changelog_file}.new"
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

# NAME: vgs_release_push_changes
# DESCRIPTION: Merges a git branch
# USAGE: vgs_release_push_changes {Type} {Version}
# REQUIRES:
#   - $version_file : the version file
#   - $changelog_file : the changelog file
# PARAMETERS:
#   1) The type of change (required)
#   2) The new version (required)
vgs_release_push_changes(){
  echo "Committing version and changelog files ($1 version $2)"
  git add "$version_file" "$changelog_file"
  git commit -m "Bump $1 version to $2"

  git push --set-upstream origin "$git_branch"

  echo 'Waiting for CI to finish'
  until [[ $(hub ci-status) == 'success' ]]; do sleep 5; done
}

# Release logic
vgs_release_main(){
  local new_version changes
  new_version=$(vgs_release_version_increment_"${release}")
  changes=$(vgs_release_get_changes)

  # the current branch
  git_branch=$(vgs_git_branch)

  vgs_git_goto_root
  vgs_release_sanity_checks

  vgs_release_write_version_to_file "$new_version"
  vgs_release_write_changes_to_file "$new_version" "$changes"
  echo "Take a minute to review the change log (Press any key to continue)"
  read -r -n1 -s
  vgs_release_push_changes "$release" "$new_version"

  vgs_git_switch_branch master
  vgs_git_merge_branch "$git_branch" "Release v${new_version}"

  vgs_git_tag_release "$new_version" "Version ${new_version} / $(date +%Y-%m-%d)"

  vgs_release_switch_branch "$git_branch"
  git rebase master
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
#   - Switch to the master branch and merge the branch
#   - Tag the release
#   - Switch back to the feature branch and rebase it from master
vgs_release(){
  # Defaults
  release='patch'
  changelog_file='CHANGELOG.md'
  version_file='VERSION'
  github_url=''

  # Process arguments
  while :
  do
    case "${1:-}" in
      -t | --type)
        release="${2:-patch}"
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
      --) # End of all options
        shift
        break
        ;;
      -*)
        e_abort "Error: Unknown option: ${1}"
        ;;
      *)  # No more options
        break
        ;;
    esac
  done

  # Run release logic
  vgs_release_main
}
