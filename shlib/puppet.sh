#!/usr/bin/env bash
# PuppetLabs Functions

# Installs Puppet agent from the official repository
vgs_puppet_agent_install(){
  local pc deb
  pc='pc1'
  deb="puppetlabs-release-${pc}-$(lsb_release -cs).deb"

  if [ -s /etc/apt/sources.list.d/puppetlabs-${pc}.list ]; then
    e_warn 'The Official PuppetLabs Repository is already configured'
    return 0
  else
    vgs_is_wget

    e_info "Downloading Puppet release package"
    wget -qO "${VGS_TMP}/${deb}" "https://apt.puppetlabs.com/${deb}"

    e_info "Installing Puppet release package"
    sudo dpkg -i "${VGS_TMP}/${deb}"

    e_info 'Updating APT'
    apt-get -qy update < /dev/null
  fi

  e_info 'Install Puppet Agent'
  apt-get -qy install puppet-agent < /dev/null
}
