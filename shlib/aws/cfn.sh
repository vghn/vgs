#!/usr/bin/env bash
# AWS CloudFormation functions

# Waits for the CloudFormation stack.
# ARGUMENTS:
#   1) Stack name
vgs_aws_cfn_wait(){
  local stack="$1"
  local status='UNKNOWN_IN_PROGRESS'

  if [[ -z "$stack" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi

  e_info "Waiting for $stack to complete ..." >&2
  until [[ $status =~ _(COMPLETE|FAILED)$ ]]; do
    status="$(aws cloudformation describe-stacks --stack-name "$1" --output text --query 'Stacks[0].StackStatus')" || return 1
    e_info " ... $stack - $status"
    sleep 5
  done

  echo "$status"

  # if status is failed or we'd rolled back, assume bad things happened
  if [[ $status =~ _FAILED$ ]] || [[ $status =~ ROLLBACK ]]; then
    return 1
  fi
}

# Gets the physical ID of a resource given a logical ID.
# ARGUMENTS:
#   1) Stack name
#   2) Resource logical ID
vgs_aws_cfn_get_resource(){
  local stack resource
  stack="$1"
  resource="$2"

  if [[ -z "$stack" ]] || [[ -z "$resource" ]]; then
    e_abort "Usage: ${FUNCNAME[0]} stack resource"
  fi

  if ! aws cloudformation describe-stack-resource \
    --stack-name "${stack}" \
    --logical-resource-id "${resource}" \
    --query "StackResourceDetail.PhysicalResourceId" \
    --output text
  then
    e_abort "Could not get the physical id of '${resource}'"
  fi
}

# Gets the value of a stack output.
# ARGUMENTS:
#   1) Stack name
#   2) Output name
vgs_aws_cfn_get_output(){
  local stack output
  stack="$1"
  output="$2"

  if [[ -z "$stack" ]] || [[ -z "$output" ]]; then
    e_abort "Usage: ${FUNCNAME[0]} stack output"
  fi

  if ! aws cloudformation describe-stacks \
    --stack-name "${stack}" \
    --query "Stacks[].Outputs[?OutputKey=='${output}'].OutputValue[]" \
    --output text
  then
    e_abort "Could not get the value of '${output}'"
  fi
}

# Gets the value of a given parameter.
# ARGUMENTS:
#   1) Stack name
#   2) Parameter
vgs_aws_cfn_get_parameter(){
  local stack parameter
  stack="$1"
  parameter="$2"

  if [[ -z "$stack" ]] || [[ -z "$parameter" ]]; then
    e_abort "Usage: ${FUNCNAME[0]} stack parameter"
  fi

  if ! aws cloudformation describe-stacks \
    --stack-name "${stack}" \
    --query "Stacks[0].Parameters[?ParameterKey=='${parameter}'].ParameterValue" \
    --output text
  then
    e_abort "Could not get the value of '${parameter}'"
  fi
}

# Lists CloudFormation stack events.
# ARGUMENTS:
#   1) Stack name (required)
vgs_aws_cfn_events() {
  local stack output
  stack="$1"; shift

  if [[ -z "$stack" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi

  if output=$(aws --color on cloudformation describe-stack-events --stack-name "$stack" --query 'sort_by(StackEvents, &Timestamp)[].{Resource: LogicalResourceId, Type: ResourceType, Status: ResourceStatus}' --output table "$@"); then
    echo "$output" | uniq -u
  else
    return $?
  fi
}

# Show all events for CF stack until update completes or fails.
# ARGUMENTS:
#   1) Stack name (required)
vgs_aws_cfn_tail() {
  local stack current final_line output previous
  stack="$1"

  if [[ -z "$stack" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi

  until echo "$current" | tail -1 | grep -E -q "${stack}.*_(COMPLETE|FAILED)"
  do
    if ! output=$(vgs_aws_cfn_events "$stack"); then
      # Something went wrong with vgs_aws_cfn_events (like stack not known)
      return 1
    fi
    if [[ -z "$output" ]]; then sleep 1; continue; fi

    current=$(echo "$output" | sed '$d')
    final_line=$(echo "$output" | tail -1)
    if [[ -z "$previous" ]]; then
      echo "$current"
    elif [[ "$current" != "$previous" ]]; then
      comm -13 <(echo "$previous") <(echo "$current")
    fi
    previous="$current"
    sleep 1
  done
  echo "$final_line"
}

# Clean display of single most recent event status for each
# resource in a CloudFormation stack
# https://github.com/alestic/aws-cloudformation-stack-status
# ARGUMENTS:
#   1) --stack: Stack name (required)
#   2) --watch: Monitor all stack resource progress live (Interrupt with Ctrl-C)
vgh_aws_cfn_watch(){
  local stack watch
  stack=
  watch=

  while [ $# -gt 0 ]; do
    case $1 in
      --stack) stack="$2";                            shift 2 ;;
      --watch) watch=1;                                 shift ;;
      --*)     echo "$0: Unrecognized option: $1" >&2; exit 1 ;;
      *) break ;;
    esac
  done

  if [ -n "$watch" ]; then
    watch -t -n1 bash -c "'source ${VGS_DIR}/load.sh; vgh_aws_cfn_watch --stack ${stack}'"
    return 0
  fi

  aws cloudformation describe-stack-events \
    --stack-name "$stack" \
    --output text \
    --query 'StackEvents[*].[ResourceStatus,LogicalResourceId,ResourceType,Timestamp]' |
  sort -k4r |
  perl -ane 'print if !$seen{$F[1]}++' |
  column -t
}

# Gets all image ids for all autoscaling launch configurations
# ARGUMENTS:
#   1) Stack name (required)
vgh_aws_cfn_params_list_images_in_use(){
  local stack images_in_use
  stack="$1"
  images_in_use=''

  if [[ -z "$stack" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi
  for launchconfig in $(aws cloudformation describe-stacks \
    --stack-name "${stack}" \
    --query "Stacks[0].Parameters[?ParameterKey=='RheaAMIId'].ParameterValue" \
    --output text)
  do
    images_in_use="${images_in_use} $(aws autoscaling describe-launch-configurations \
      --launch-configuration-names "$launchconfig" \
      --query "LaunchConfigurations[].ImageId" \
      --output text)"
  done
  echo "${images_in_use/ /}"
}

# Gets all image ids for all autoscaling launch configurations
# ARGUMENTS:
#   1) Stack name (required)
vgh_aws_cfn_list_images_in_use(){
  local stack images_in_use
  stack="$1"
  images_in_use=''
  if [[ -z "$stack" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi
  for launchconfig in $(aws cloudformation describe-stack-resources \
    --stack-name "${stack}" \
    --query "StackResources[?ResourceType=='AWS::AutoScaling::LaunchConfiguration'].PhysicalResourceId" \
    --output text)
  do
    images_in_use="${images_in_use} $(aws autoscaling describe-launch-configurations \
      --launch-configuration-names "$launchconfig" \
      --query "LaunchConfigurations[].ImageId" \
      --output text)"
  done
  echo "${images_in_use/ /}"
}
