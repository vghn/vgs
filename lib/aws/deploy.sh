#!/usr/bin/env bash
# AWS CodeDeploy functions

# NAME: vgs_aws_deploy_application_ensure
# DESCRIPTION: Ensure AWS CodeDeploy Application exists. Returns the id.
# USAGE: vgs_aws_deploy_application_ensure {Application name}
# PARAMETERS:
#   1) The application name (required)
vgs_aws_deploy_application_ensure(){
  local name="${1:?Must specify the application name as the only argument}"
  aws deploy get-application \
    --application-name "$name" \
    --output text \
    --query 'application.applicationId' || \
  aws deploy create-application \
    --application-name "$name" \
    --output text \
    --query 'application.applicationId' || \
  return 1
}

# NAME: vgs_aws_deploy_group_ensure
# DESCRIPTION: Creates or updates an AWS CodeDeploy deployment group.
#              Returns the id.
# USAGE: vgs_aws_deploy_group_ensure {App} {Group} {Autoscaling Groups}
#        {Configuration Name} {Service Role ARN}
# PARAMETERS:
#   1) The application name (required)
#   2) The deployment group name (required)
#   3) A list of associated Auto Scaling groups (required)
#   4) The deployment configuration name (required)
#   5) The AWS CodeDeploy service role ARN (required)
vgs_aws_deploy_group_ensure(){
  local app grp asg cfg arn
  app=${1:?Must specify the application name as the 1st argument}
  grp=${2:?Must specify the deployment group name as the 2nd argument}
  asg=${3:?Must specify the autoscaling group name as the 3rd argument}
  cfg=${4:?Must specify the deployment configuration name as the 4th argument}
  arn=${5:?Must specify the service role arn as the 5th argument}

  local id

  if vgs_aws_deploy_group_exists "$app" "$grp"; then
    id=$(aws deploy update-deployment-group \
      --application-name "$app" \
      --current-deployment-group-name "$grp" \
      --auto-scaling-groups "$asg" \
      --deployment-config-name "$cfg" \
      --service-role-arn "$arn" \
      --output text \
      --query 'deploymentGroupInfo.deploymentGroupId')
  else
    id=$(aws deploy create-deployment-group \
      --application-name "$app" \
      --deployment-group-name "$grp" \
      --auto-scaling-groups "$asg" \
      --deployment-config-name "$cfg" \
      --service-role-arn "$arn" \
      --output text \
      --query 'deploymentGroupInfo.deploymentGroupId')
  fi
  echo "$id"
}

# NAME: vgs_aws_deploy_group_exists
# DESCRIPTION: Returns the group id if the given deployment group exists.
# USAGE: vgs_aws_deploy_group_exists {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_group_exists() {
  local app grp
  app=${1:?Must specify the application name as the 1st argument}
  grp=${2:?Must specify the deployment group name as the 2nd argument}

  local id

  if id=$(aws deploy get-deployment-group \
    --application-name "$app" \
    --deployment-group-name "$grp" \
    --output text \
    --query 'deploymentGroupInfo.deploymentGroupId')
  then
    echo "$id"
  else
    return 1
  fi
}

# NAME: vgs_aws_deploy_list_running_deployments
# DESCRIPTION: Returns the a list of running deployments for the given
# CodeDeploy application and group.
# USAGE: vgs_aws_deploy_list_running_deployments {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_list_running_deployments() {
  local app grp
  app=${1:?Must specify the application name as the 1st argument}
  grp=${2:?Must specify the deployment group name as the 2nd argument}

  aws deploy list-deployments \
    --application-name "$app" \
    --deployment-group-name "$grp" \
    --include-only-statuses Queued InProgress \
    --output text \
    --query 'deployments'
}

# NAME: vgs_aws_deploy_wait
# DESCRIPTION: Waits until there are no other deployments in progress for the
# given CodeDeploy application and group.
# USAGE: vgs_aws_deploy_wait {App} {Group}
# PARAMETERS:
#   1) The application name
#   2) The deployment group name
vgs_aws_deploy_wait() {
  local app grp
  app=${1:?Must specify the application name as the 1st argument}
  grp=${2:?Must specify the deployment group name as the 2nd argument}

  e_info 'Waiting for other deployments to finish ...'
  until [[ -z "$(vgs_aws_deploy_list_running_deployments "$app" "$grp")" ]]; do
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
  local app grp bucket key bundle config
  app=${1:?Must specify the application name as the 1st argument}
  grp=${2:?Must specify the deployment group name as the 2nd argument}
  bucket=${3:?Must specify the S3 bucket name as the 3rd argument}
  key=${4:?Must specify the S3 key name as the 4th argument}
  bundle=${5:?Must specify the bundle type as the 5th argument}
  config=${5:?Must specify the deployment configuration name as the 5th argument}

  if vgs_aws_deploy_group_exists "$@"; then
    vgs_aws_deploy_wait "$@"

    e_info "Creating deployment for application '${app}', group '${grp}'"
    aws deploy create-deployment \
      --application-name "$app" \
      --s3-location bucket="${bucket}",key="${key}",bundleType="${bundle}" \
      --deployment-group-name "$grp" \
      --deployment-config-name "$config" \
      --output text \
      --query 'deploymentId' || \
    e_abort 'Could not create deployment'
  else
    e_warn "The '${grp}' group does not exist in the '${app}' application"
  fi
}
