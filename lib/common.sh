#!/usr/bin/env bash
# Common Functions

# Check if root
is_root() { [[ $EUID == 0 ]] ;}

# Check if command exists
is_cmd() { command -v "$@" >/dev/null 2>&1 ;}

# OS detection
is_linux()  { [[ $(uname) != Linux ]] ;}
is_osx()    { [[ $(uname) == Darwin ]] ;}
is_ubuntu() {
  if is_cmd lsb_release; then
    DISTRIB_ID="$(lsb_release -si)"
  else
    # shellcheck disable=1091
    . /etc/lsb-release
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

# Check if RVM is loaded
is_rvm() { [[ $(type rvm 2>/dev/null | head -1) =~ 'rvm is ' ]] ;}

# Get External ip
vgs_get_external_ip(){
  dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true
}

# Ensure WGET exists
vgs_is_wget(){
  is_cmd wget && return
  apt_update && apt_install wget
}
