#!/usr/bin/env bash
# AWS Elastic Container Service functions

# Returns a list of EC2 Container Service Clusters
vgs_aws_ecs_list_clusters(){
  if ! aws ecs list-clusters --query 'clusterArns[]' --output text; then
    e_abort 'Could not list clusters'
  fi
}

# Returns the desired running count for the specified ECS Service
# ARGUMENTS:
#   1) The cluster name (required)
#   2) The service name (required)
vgs_aws_ecs_service_desired_running_count(){
  local cluster=${1:?Must specify the cluster name as the 1st argument}
  local service=${2:?Must specify the service name as the 2nd argument}

  if ! count="$(aws ecs describe-services \
    --cluster "$cluster" \
    --services "$service" \
    --query "services[0].runningCount" \
    --output text || true)"
  then
    e_abort "Could not get the running count for the ${service} service in cluster ${cluster}"
  fi

  [[ "$count" =~ ^[0-9]+$ ]] && echo "$count" || echo 0
}
