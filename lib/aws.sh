#!/usr/bin/env bash
# AWS functions

# AWS Region
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Load functions
for file in ${VGS_DIR}/lib/aws/*.sh; do
  # shellcheck disable=1090
  . "$file"
done

# AWS MetaData Service
vgs_aws_get_metadata(){
  wget --timeout=2 --tries=0 -qO- "http://169.254.169.254/latest/meta-data/${*}"
}
