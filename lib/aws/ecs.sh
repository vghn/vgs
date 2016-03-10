#!/usr/bin/env bash
# AWS Elastic Container Service functions

# Returns a list of EC2 Container Service Clusters
vgs_aws_ecs_list_clusters(){
  if output=$(aws ecs list-clusters --query 'clusterArns[]' --output text); then
    echo "$output"
  else
    return $?
  fi
}
