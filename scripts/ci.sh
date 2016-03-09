#!/usr/bin/env bash
# Continuous Integration Tasks

# Immediately exit on errors
set -euo pipefail

# VARs
APPDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd -P)"
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
VERSION_FILE="${APPDIR}/VERSION"
VERSION=$(cat "$VERSION_FILE")
GITSHA1=${CIRCLE_SHA1:-$(git rev-parse --short HEAD 2>/dev/null)}
TARBALL="vgs-${VERSION}-${GITSHA1}.tgz"
PKG_DIR=${CIRCLE_ARTIFACTS:-'./pkg'}
TGZPATH="${PKG_DIR}/${TARBALL}"
GIT_BRANCH=${CIRCLE_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null)}
S3_PREFIX=$GIT_BRANCH

# Load functions
# shellcheck disable=1090
[ -s "${APPDIR}/load" ] && . "${APPDIR}/load"

# Sanity checks
sanity_checks(){
  # Create packaging directory if it does not exists
  [[ -d "$PKG_DIR" ]] || mkdir -p "$PKG_DIR"
  # Remove existing an existing archive if it exists
  [[ -s "$TGZPATH" ]] && rm -f "$TGZPATH"
}

# Archive all system assets to a tarball ready for upload
archive_assets(){
  e_info "Archiving as ${TGZPATH}..."
  tar czvf "$TGZPATH" lib scripts load LICENSE README.md VERSION
  e_info 'Achiving complete.'
}

# Upload to S3 bucket then copy as latest.tgz
upload_to_s3(){
  if [[ "$S3_PREFIX" == 'master' ]]; then
    local dest="s3://${AWS_S3_BUCKET}"
  else
    local dest="s3://${AWS_S3_BUCKET}/${S3_PREFIX}"
  fi

  e_info "Uploading to '${dest}' S3 bucket..."
  aws s3 cp --acl public-read "$TGZPATH" "$dest"
  aws s3 cp --acl public-read "${dest}/${TARBALL}" "${dest}/vgs-latest.tgz"
  e_info 'S3 upload complete.'
}

# Use shellcheck to lint all .sh files
lint_sh_files(){
  while IFS= read -r -d '' file; do
    shellcheck "$file" && e_ok "Sucessfully linted $file"
  done < <(find . -type f -name '*.sh' -print0)
}

# Process arguments
case "${1:-}" in
  install)
    ;;
  test)
    lint_sh_files
    ;;
  deploy)
    sanity_checks && archive_assets && upload_to_s3
    ;;
  *)
    echo "USAGE: ${BASH_SOURCE[0]} [install | test | deploy]" >&2; exit 1
    ;;
esac
