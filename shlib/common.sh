#!/usr/bin/env bash
# Common Functions

# set env loaded flag if not yet set
: vgs_env_loaded:"${vgs_env_loaded:=0}":
# increase load count counter
: vgs_env_loaded:$(( vgs_env_loaded+=1 )):

# Check if root
is_root() { [[ $EUID == 0 ]] ;}

# Check if command exists
is_cmd() { command -v "$@" >/dev/null 2>&1 ;}

# OS detection
is_linux()  { [[ $(uname) == Linux ]] ;}
is_osx()    { [[ $(uname) == Darwin ]] ;}
is_ubuntu() {
  if is_cmd lsb_release; then
    DISTRIB_ID="$(lsb_release -si)"
  else
    # shellcheck disable=1091
    [[ -s /etc/lsb-release ]] && . /etc/lsb-release
  fi
  [[ "$DISTRIB_ID" =~ Ubuntu ]]
}

# Get codename
get_dist() {
  if is_cmd lsb_release; then
    lsb_release -cs
  else
    # shellcheck disable=1091
    . /etc/lsb-release
    echo "$DISTRIB_CODENAME"
  fi
}

# APT install package
apt_install(){ e_info "Installing $*"; apt-get -qy install "$@" < /dev/null ;}

# Update APT
apt_update() { e_info 'Updating APT' && apt-get -qy update < /dev/null ;}

# Upgrade box
apt_upgrade(){ e_info 'Upgrading box' && sudo apt-get -qy upgrade < /dev/null ;}

# Load private environment
load_env(){
  if [[ -s "${APPDIR}/.env" ]]; then
    # shellcheck disable=1090
    . "${APPDIR}/.env" 2>/dev/null || true
  elif [[ -s "${APPDIR}/.env.gpg" ]]; then
    # shellcheck disable=1090
    . <( gpg --batch --yes --pinentry-mode loopback --passphrase "$( echo "$ENCRYPT_KEY" | base64 --decode --ignore-garbage )" --decrypt "${APPDIR}/.env.gpg" ) 2>/dev/null || true
  fi

  # Detect environment (fallback to production)
  detect_environment 2>/dev/null || ENVTYPE="${ENVTYPE:-production}"
}

# Detect environment
detect_environment(){
  # Git environment
  GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo '')
  GIT_SHA1=$(git rev-parse --short HEAD 2>/dev/null || echo '0')
  if [[ -n "${ENVTYPE:-}" ]]; then # If env var
    ENVTYPE="$ENVTYPE"
  elif [[ -n "${GIT_BRANCH:-}" ]]; then # If git branch
    ENVTYPE="$GIT_BRANCH"
  elif [[ -n "${TRAVIS_BRANCH:-}" ]]; then # If TravisCI git branch
    ENVTYPE="$TRAVIS_BRANCH"
  elif [[ -n "${CIRCLE_BRANCH:-}" ]]; then # If CircleCI git branch
    ENVTYPE="$CIRCLE_BRANCH"
  elif [[ -n "${DEPLOYMENT_GROUP_NAME:-}" ]]; then # If AWS CodeDeploy hook
    ENVTYPE="$DEPLOYMENT_GROUP_NAME"
  else
    ENVTYPE=${ENVTYPE:-production}
  fi

  # Rename master to production
  if [[ "$ENVTYPE" == 'master' ]]; then
    ENVTYPE='production'
  fi

  # CI environment
  IS_CI=${CI:-false}
  IS_PR=${PR:-false}
  BUILD=${GIT_SHA1:-0}
  if [[ ${CIRCLECI:-false} == true ]]; then
    export IS_PR=${CIRCLE_PR_NUMBER:-}
    export BUILD=${CIRCLE_BUILD_NUM:-}
  elif [[ ${TRAVIS:-false} == true ]]; then
    export IS_PR=${TRAVIS_PULL_REQUEST:-false}
    export BUILD=${TRAVIS_BUILD_NUMBER:-}
  fi

  export ENVTYPE GIT_BRANCH GIT_SHA1 IS_CI IS_PR BUILD
}

# Check if RVM is loaded
is_rvm() { [[ $(type rvm 2>/dev/null | head -1) =~ 'rvm is ' ]] ;}

# Set bundle directory
set_bundle_directory(){
  cd "${1:-}" || return 1
  export BUNDLE_GEMFILE="${PWD}/Gemfile"
}

# Get External ip
vgs_get_external_ip(){
  dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true
}

# Ensure WGET exists
vgs_is_wget(){
  is_cmd wget && return 0
  apt_update && apt_install wget
}

# Ensure NFS tools are installed
vgs_is_nfs(){
  is_cmd mount.nfs4 && return 0
  apt_update && apt_install nfs-common
}
