#!/usr/bin/env bash
# AWS S3 functions

# NAME: vgs_aws_s3_generate_presigned_url
# DESCRIPTION: Returns a temporary presigned url for an existing S3 object.
# USAGE: vgs_aws_s3_generate_presigned_url {Bucket} {Key} {Expiration}
# PARAMETERS:
#   1) The bucket name (required)
#   2) The key name (required)
#   3) The expiration time, in seconds (defaults: 600)
vgs_aws_s3_generate_presigned_url(){
  local bucket key expires
  bucket=${1:?}
  key=${2:?}
  expires=${3:?}

  python <<< "import boto3; print boto3.client('s3').generate_presigned_url('get_object', Params = {'Bucket': '${bucket}', 'Key': '${key}'}, ExpiresIn = ${expires})"
}

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
  bucket=${1:?}
  prefix=${2:?}
  keep=${3:?}

  aws s3api list-objects \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --query "reverse(sort_by(Contents, &LastModified))[${keep}:].Key" \
    --output text || e_abort 'Could not list S3 objects'
}
