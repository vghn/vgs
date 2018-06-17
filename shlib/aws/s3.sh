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

  if ! aws s3api list-objects \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --query "reverse(sort_by(Contents, &LastModified))[${keep}:].Key" \
    --output text
  then
    log 'Could not list S3 objects' >&2
  fi
}

# NAME: vgs_aws_s3_get_latest_object
# DESCRIPTION: Returns the last S3 object (sorted by last modified date).
# USAGE: vgs_aws_s3_get_latest_object {Bucket} {Key Prefix}
# PARAMETERS:
#   1) The bucket name (required)
#   2) The key prefix (required)
vgs_aws_s3_get_latest_object(){
  local bucket prefix
  bucket=${1:?Must specify the S3 bucket name as the 1st argument}
  prefix=${2:?Must specify the S3 prefix as the 2nd argument}

  if ! aws s3api list-objects \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --query 'reverse(sort_by(Contents, &LastModified))[0].Key' \
    --output text
  then
    log 'Could not retrieve the last S3 object!' >&2
  fi
}

# NAME: vgs_aws_s3_upload_encrypted
# DESCRIPTION: Archives and encrypts a local path and uploads it to AWS S3.
# USAGE: vgs_aws_s3_upload_encrypted {GPG Recipient} {Local Path} {S3 Path}
# PARAMETERS:
#   1) The GPG Recipient (required)
#   2) The local path (required)
#   3) The S3 path (required; ex: "s3://vgsec/$(date +"%Y%m%d_%H%M%S").tar.xz.gpg")
vgs_aws_s3_upload_encrypted(){
  local recipient local_path s3_path
  recipient="${1:?Must specify GPG recipient as the 1st argument}"
  local_path=${2:?Must specify the S3 bucket name as the 2nd argument}
  s3_path=${3:?Must specify the S3 prefix as the 3rd argument}

  if [[ "${s3_path}" =~ ^s3://.*\.tar\.xz\.gpg$ ]]; then
    echo "Encrypting ${local_path}"
    tar cJ -C "$local_path" . | gpg --encrypt --sign --recipient "$recipient" --cipher-algo AES256 --s2k-digest-algo SHA512 | aws s3 cp --no-progress --sse --acl private - "${s3_path}"
    log "Secret files uploaded to ${s3_path}"
  else
    log "${s3_path} not a recognizable S3 path!"
    log "It needs to start with 's3://' and end with '.tar.xz.gpg'"
    log "Ex: 's3://vgsec/$(date +"%Y%m%d_%H%M%S").tar.xz.gpg'"
  fi
}

# NAME: vgs_aws_s3_download_decrypt
# DESCRIPTION: Decrypts and extracts an the latest AWS S3 stored object
# USAGE: vgs_aws_s3_download_decrypt {Bucket} {Key Prefix} {Local Path}
# PARAMETERS:
#   1) The bucket name (required)
#   2) The key prefix (required)
#   3) The local path (required)
vgs_aws_s3_download_decrypt(){
  local bucket prefix local_path
  bucket=${1:?Must specify the S3 bucket name as the 1st argument}
  prefix=${2:?Must specify the S3 prefix as the 2nd argument}
  local_path=${3:?Must specify the local path as the 3rd argument}

  mkdir -p "$local_path"
  aws s3 cp --no-progress "s3://${bucket}/$(aws s3api list-objects --bucket "$bucket" --query 'reverse(sort_by(Contents, &LastModified))[0].Key' --output text)" - | gpg --decrypt | tar xJ --directory "$local_path"
  log "Secret files saved at ${local_path}"
}