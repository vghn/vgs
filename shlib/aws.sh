#!/usr/bin/env bash
# AWS functions

# NAME: vgs_aws_configure
# DESCRIPTION: Configure AWS Credentials
# USAGE: vgs_aws_configure {Profile} {Access Key} {Secret Key} {Region}
# PARAMETERS:
#   1) Prodile name
#   2) AWS access key
#   3) AWS secret key
#   4) AWS region
vgs_aws_configure(){
  local profile="${1:?Must specify the profile name as the 1st argument}"
  local aws_access_key_id="${2:?Must specify the access key id as the 2nd argument}"
  local aws_secret_access_key="${3:?Must specify the secret access key as the 3rd argument}"
  local region="${4:?Must specify the region as the 4th argument}"

  if is_cmd aws; then
    aws configure --profile "${profile}" get aws_access_key_id >/dev/null 2>&1 || \
      aws configure --profile "${profile}" set aws_access_key_id "${aws_access_key_id}"
    aws configure --profile "${profile}" get aws_secret_access_key >/dev/null 2>&1 || \
      aws configure --profile "${profile}" set aws_secret_access_key "${aws_secret_access_key}"
    aws configure --profile "${profile}" get region >/dev/null 2>&1 || \
      aws configure --profile "${profile}" set region "${region}"
  fi
}

# AWS MetaData Service
vgs_aws_get_metadata(){
  wget --timeout=2 --tries=0 -qO- "http://169.254.169.254/latest/meta-data/${*}"
}

# Load functions
for file in ${VGS_SHLIB}/aws/*.sh; do
  # shellcheck disable=1090
  . "$file"
done
