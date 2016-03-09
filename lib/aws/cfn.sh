#!/usr/bin/env bash
# AWS CloudFormation functions

# NAME: vgs_aws_cfn_wait
# DESCRIPTION: Waits for the CloudFormation stack.
# USAGE: vgs_aws_cfn_wait {Stack}
# PARAMETERS:
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

# NAME: vgs_aws_cfn_get_output
# DESCRIPTION: Gets the value of a stack output.
# USAGE: vgs_aws_cfn_get_output {Stack} {Output}
# PARAMETERS:
#   1) Stack name
#   1) Output name
vgs_aws_cfn_get_output(){
  local stack="$1"
  local output="$2"

  if [[ -z "$stack" ]] || [[ -z "$output" ]]; then e_abort "Usage: ${FUNCNAME[0]} stack output"; fi

  if output_value=$(aws cloudformation describe-stacks --stack-name "${stack}" --query "Stacks[].Outputs[?OutputKey=='${output}'].OutputValue[]" --output text); then
    echo "$output_value"
  else
    return $?
  fi
}

# NAME: vgs_aws_cfn_events
# DESCRIPTION: Lists CloudFormation stack events.
# USAGE: vgs_aws_cfn_events {Stack name}
# PARAMETERS:
#   1) Stack name (required)
vgs_aws_cfn_events() {
  if [ -z "$1" ] ; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi
  local stack
  stack="$(basename "$1" .json)"
  shift
  local output
  if output=$(aws --color on cloudformation describe-stack-events --stack-name "$stack" --query 'sort_by(StackEvents, &Timestamp)[].{Resource: LogicalResourceId, Type: ResourceType, Status: ResourceStatus}' --output table "$@"); then
    echo "$output" | uniq -u
  else
    return $?
  fi
}

# NAME: vgs_aws_cfn_tail
# DESCRIPTION: Show all events for CF stack until update completes or fails.
# USAGE: vgs_aws_cfn_tail {Stack name}
# PARAMETERS:
#   1) Stack name (required)
vgs_aws_cfn_tail() {
  if [ -z "$1" ] ; then e_abort "Usage: ${FUNCNAME[0]} stack"; fi
  local stack
  stack="$(basename "$1" .json)"
  local current
  local final_line
  local output
  local previous
  until echo "$current" | tail -1 | egrep -q "${stack}.*_(COMPLETE|FAILED)"
  do
    if ! output=$(vgs_aws_cfn_events "$stack"); then
      # Something went wrong with cf_events (like stack not known)
      return 1
    fi
    if [ -z "$output" ]; then sleep 1; continue; fi

    current=$(echo "$output" | sed '$d')
    final_line=$(echo "$output" | tail -1)
    if [ -z "$previous" ]; then
      echo "$current"
    elif [ "$current" != "$previous" ]; then
      comm -13 <(echo "$previous") <(echo "$current")
    fi
    previous="$current"
    sleep 1
  done
  echo "$final_line"
}
