#!/usr/bin/env bash
# AWS S3 functions

# NAME: vgs_aws_s3_list_old_keys
# DESCRIPTION: Returns a list of S3 objects, sorted by last modified date.
#              The newest X items are excluded.
#              * http://jmespath.org/specification.html#sort-by
#              * http://jmespath.org/specification.html#reverse
#              * http://jmespath.org/tutorial.html#slicing
# USAGE: vgs_aws_s3_list_old_keys {Bucket} {Key Prefix} {Keep}
# PARAMETERS:
#   1) The bucket name (required)
#   2) The key prefix (required)
#   3) How many items to keep (required)
vgs_aws_s3_list_old_keys(){
  local bucket prefix keep
  bucket=${1:?Must specify the S3 bucket name as the 1st argument}
  prefix=${2:?Must specify the S3 prefix as the 2nd argument}
  keep=${3:?Must specify how many items to keep as the 3rd argument}

  aws s3api list-objects \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --query "reverse(sort_by(Contents, &LastModified))[${keep}:].Key" \
    --output text || e_abort 'Could not list S3 objects'
}
