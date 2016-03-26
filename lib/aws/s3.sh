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
