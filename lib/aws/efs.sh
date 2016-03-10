#!/usr/bin/env bash
# AWS Elastic Container Service functions

# NAME: vgs_aws_efs_mount
# DESCRIPTION: Mount AWS Elastic File System
# USAGE: vgs_aws_efs_mount {EFS ID} {path}
# PARAMETERS:
#   1) Elastic File System ID (required)
#   2) The local path where to mount the EFS
vgs_aws_efs_mount(){
  local id=$1
  local path=$2
  local zone; zone=$(vgs_aws_ec2_get_instance_az)
  local mnt="${zone}.${id}.efs.${zone%?}.amazonaws.com:/"

  # Check arguments
  if [ $# -eq 0 ] ; then e_abort "Usage: ${FUNCNAME[0]} EFS_ID PATH"; fi
  # Check if NFS tools are installed
  if ! is_cmd mount.nfs4; then echo "Install 'nfs-common' first"; return 1; fi
  # Check if already mounted
  if mount | grep -q "$mnt"; then echo "'${mnt}' already mounted"; return; fi

  if [ ! -d "$path" ]; then
    e_info "Creating '${path}' and mounting Elastic File System"
    mkdir -p "$path"
  else
    e_info "'${path}' already present"
  fi
  echo "Mounting Elastic File System at '${path}'"
  mount -t nfs4 "$mnt" "$path"
}
