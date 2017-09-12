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
  local region; region=$(vgs_aws_ec2_get_instance_region)
  local mnt="${zone}.${id}.efs.${region}.amazonaws.com:/"

  # Check arguments
  if [ $# -eq 0 ] ; then e_abort "Usage: ${FUNCNAME[0]} EFS_ID PATH"; fi

  # Ensure NFS tools are installed
  vgs_is_nfs

  # Check if already mounted
  if mount | grep -q "$mnt"; then e_info "'${mnt}' already mounted"; return 0; fi

  if [ ! -d "$path" ]; then
    e_info "Creating '${path}' and mounting Elastic File System"
    mkdir -p "$path"
  else
    e_info "'${path}' already present"
  fi

  e_info "Mounting Elastic File System at '${path}'"
  mount -t nfs4 -o nfsvers=4.1 "$mnt" "$path"

  e_info "Check ${path} mount point",
  if mountpoint -q "$path"; then
    e_ok "${path} seems to be mounted ok"
  else
    e_abort "${path} does not seem to be mounted"
  fi
}
