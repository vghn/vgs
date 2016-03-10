#!/usr/bin/env bash
# AWS CodeDeploy functions

# NAME: vgs_aws_deploy_application_create
# DESCRIPTION: Ensure AWS CodeDeploy Application exists. Returns the id.
# USAGE: vgs_aws_deploy_application_create {Application name}
# PARAMETERS:
#   1) The application name (required)
vgs_aws_deploy_application_create(){
  local name="${1:?}"
  aws deploy get-application \
    --application-name "$name" \
    --output text \
    --query 'application.applicationId' || \
  aws deploy create-application \
    --application-name "$name" \
    --output text \
    --query 'application.applicationId' || \
  e_abort 'Could not create application'
}

# NAME: aws_deploy_create_deployment_group
# DESCRIPTION: Creates an AWS CodeDeploy deployment group.
# USAGE: aws_deploy_create_deployment_group {App} {Group} {Autoscaling Groups}
#        {Configuration Name} {Service Role ARN}
# PARAMETERS:
#   1) The application name (required)
#   2) The deployment group name (required)
#   3) A list of associated Auto Scaling groups (required)
#   4) The deployment configuration name (required)
#   5) The AWS CodeDeploy service role ARN (required)
vgs_aws_deploy_group_create(){
  local app=${1:?}
  local group=${2:?}
  local asg=${3:?}
  local cfg=${4:?}
  local role=${5:?}

  aws deploy get-deployment-group \
    --application-name "$app" \
    --deployment-group-name "$group" \
    --output text \
    --query 'deploymentGroupInfo.deploymentGroupId' || \
  aws deploy create-deployment-group \
    --application-name "$app" \
    --deployment-group-name "$group" \
    --auto-scaling-groups "$asg" \
    --deployment-config-name "$cfg" \
    --service-role-arn "$role" \
    --output text \
    --query 'deploymentGroupInfo.deploymentGroupId' || \
  aws deploy create-deployment-group \
    --application-name "$app" \
    --current-deployment-group-name "$group" \
    --auto-scaling-groups "$asg" \
    --deployment-config-name "$cfg" \
    --service-role-arn "$role" \
    --output text \
    --query 'deploymentGroupInfo.deploymentGroupId' || \
  e_abort "Could not create or update the '${group}' deployment group"
}

# NAME: vgs_aws_deploy_group_exists
# DESCRIPTION: Returns true if the given deployment group exists.
# USAGE: vgs_aws_deploy_group_exists {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_group_exists() {
  local app=$1
  local group=$2

  aws deploy get-deployment-group \
    --query 'deploymentGroupInfo.deploymentGroupId' --output text \
    --application-name "$1" \
    --deployment-group-name "$2" >/dev/null
}

# NAME: vgs_aws_deploy_list_running_deployments
# DESCRIPTION: Returns the a list of running deployments for the given
# CodeDeploy application and group.
# USAGE: vgs_aws_deploy_list_running_deployments {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_list_running_deployments() {
  local app=$1
  local group=$2

  aws deploy list-deployments \
    --output text \
    --query 'deployments' \
    --application-name "$1" \
    --deployment-group-name "$2" \
    --include-only-statuses Queued InProgress
}

# NAME: vgs_aws_deploy_wait
# DESCRIPTION: Waits until there are no other deployments in progress for the
# given CodeDeploy application and group.
# USAGE: vgs_aws_deploy_wait {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_wait() {
  local app=$1
  local group=$2

  e_info 'Waiting for other deployments to finish ...'
  until [[ -z "$(vgs_aws_deploy_list_running_deployments "$app" "$group")" ]]; do
    sleep 5
  done
  e_ok ' Done.'
}

# NAME: vgs_aws_deploy_create_deployment
# DESCRIPTION: Creates a CodeDeploy revision.
# USAGE: vgs_aws_deploy_create_deployment {App} {Group} {Bucket} {Key} {Bundle} {Config}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
#   3) The S3 bucket name
#   4) The S3 key name
#   5) The bundle type ("tar"|"tgz"|"zip")
#   6) The deployment config name
vgs_aws_deploy_create_deployment(){
  local app=$1
  local group=$2
  local bucket=$3
  local key=$4
  local bundle=$5
  local config=$6

  if aws_deploy_group_exists "$@"; then
    aws_deploy_wait "$@"

    e_info "Creating deployment for application '${app}', group '${group}'"
    aws deploy create-deployment \
      --application-name "$app" \
      --s3-location bucket="${bucket}",key="${key}",bundleType="${bundle}" \
      --deployment-group-name "$group" \
      --deployment-config-name "$config" \
      --output text \
      --query 'deploymentId' || \
    e_abort 'Could not create deployment'
  else
    e_warn "The '${group}' group does not exist in the '${app}' application"
  fi
}
