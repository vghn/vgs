#!/usr/bin/env bash
# AWS functions

# Configure AWS Credentials
# ARGUMENTS:
#   1) Profile name
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

# Configure AWS Temporary Credentials
# ARGUMENTS:
#   1) AWS access key
#   2) AWS secret key
#   3) AWS role arn
vgs_aws_credentials(){
  local aws_access_key_id="${1:?Must specify the access key id as the 1st argument}"
  local aws_secret_access_key="${2:?Must specify the secret access key as the 2nd argument}"
  local aws_role_arn="${3:?Must specify the role arn as the 3rd argument}"

  e_info 'Get temporary credentials for AWS'

  # Clear out existing AWS session environment, or the awscli call will fail
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

  # Read temporary credentials
  read -r -a AWS_STS <<< "$( \
    AWS_ACCESS_KEY_ID="${aws_access_key_id:-}" \
    AWS_SECRET_ACCESS_KEY="${aws_secret_access_key:-}" \
    aws sts assume-role --output text \
    --role-arn "${aws_role_arn:-}" \
    --role-session-name "$(hostname)_$(date +%Y%m%d)" \
    --duration-seconds 900 \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    )"

  # Export temporary credentials
  export AWS_ACCESS_KEY_ID="${AWS_STS[0]}"
  export AWS_SECRET_ACCESS_KEY="${AWS_STS[1]}"
  export AWS_SESSION_TOKEN="${AWS_STS[2]}"
}

# AWS MetaData Service
vgs_aws_get_metadata(){
  wget --timeout=2 --tries=0 -qO- "http://169.254.169.254/latest/meta-data/${*}"
}

# Load functions
for file in "${VGS_SHLIB}"/aws/*.sh; do
  # shellcheck disable=1090
  . "$file"
done
