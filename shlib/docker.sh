#!/usr/bin/env bash
# Docker Functions

# Returns true if the given containers are running
# ARGUMENTS:
#   1) One or more container names or ids
vgs_docker_container_is_running() {
  for container in "${@}"; do
    if [[ $(docker inspect --format='{{.State.Running}}' "${container}" 2>/dev/null) == true ]]; then
      e_ok "'$container' is running."
    else
      e_abort "'$container' container is not running!"
    fi
  done
}

# Returns true if the given containers returned a 0 exit code
# ARGUMENTS:
#   1) One or more container names or ids
vgs_docker_container_exited_clean() {
  for container in "${@}"; do
    [[ $(docker inspect --format='{{.State.ExitCode}}' "${container}" 2>/dev/null) == 0 ]] || \
      e_abort "'$container' container did not exit cleanly!"
  done
}

# Loads a docker image from a local archive.
# ARGUMENTS:
#   1) The path to the archive
vgs_docker_image_load(){
  local path=$1
  if [[ -e $path ]]; then
    e_info "Loading image from '${path}'"
    docker load -i "$path"
  else
    e_warn "The Docker image '${path}' does not exist"
  fi
}

# Saves a compressed docker image to a local archive.
# ARGUMENTS:
#   1) Image name (Ex: user/image:tag)
#   2) The path to the archive (Ex: /tmp/test.tgz)
vgs_docker_image_save(){
  local name=$1
  local path=$2
  e_info "Saving image '${name}' to '${path}'"
  mkdir -p "$(dirname "$path")"
  docker save "$name" | gzip -c > "$path"
}

# Refresh a cached docker image.
# ARGUMENTS:
#   1) Image name
#   2) The path to the archive
vgs_docker_image_refresh_cache(){
  local name=$1
  local path=$2
  vgs_docker_image_load "$path"
  docker pull "$name"
  vgs_docker_image_save "$@"
}
