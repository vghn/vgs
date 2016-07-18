#!/usr/bin/env bash
# AWS EC2 functions

# Returns the EC2 instance ID for the local instance
vgs_aws_ec2_get_instance_id() {
  vgs_aws_get_metadata instance-id
}

# Returns the the AWS availability zone
vgs_aws_ec2_get_instance_az() {
  local az; az=$(vgs_aws_get_metadata placement/availability-zone)
  if [[ "$az" =~ ^[a-z]{2}-[a-z]+-[0-9][a-z]$ ]]; then
    echo "$az"
  else
    e_abort "Invalid availability zone name: '${az}'"
  fi
}

# Returns the the AWS region
vgs_aws_ec2_get_instance_region() {
  local zone; zone=$(vgs_aws_ec2_get_instance_az)
  echo "${zone%?}"
}

# Returns a list of running instances
vgh_aws_ec2_list_running_instances(){
  aws ec2 describe-instances \
    --filters 'Name=instance-state-name,Values=running' \
    --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key=='Name'].Value}" \
    --output table
}

# NAME: vgs_aws_ec2_list_all_tags
# DESCRIPTION: Returns all EC2 tags associated with the current instance.
# Prefixes each one with `ec2_tag_`. Useful for puppet facts.
vgs_aws_ec2_list_all_tags(){
  aws --output text ec2 describe-tags \
    --filters "Name=resource-id,Values=$(vgs_aws_ec2_get_instance_id)" \
    --query "Tags[*].[join(\`=\`,[Key,Value])]" 2>/dev/null | \
    awk '{print tolower($0)}' | \
    sed 's/.*/ec2_tag_&/'
}

# NAME: vgs_aws_ec2_get_tag
# DESCRIPTION: Gets the value of an ec2 tag.
# USAGE: vgs_aws_ec2_get_tag {Key Name} {Resource ID}
# PARAMETERS:
#   1) The key name (defaults to 'Name')
#   2) The resource id (defaults to the current instance id)
vgs_aws_ec2_get_tag(){
  local name=${1:-Name}
  local instance_id; instance_id=$(vgs_aws_ec2_get_instance_id)
  local resource=${2:-$instance_id}

  aws --output text ec2 describe-tags \
    --filters "Name=resource-id,Values=${resource}" "Name=key,Values=$name" \
    --query "Tags[*].[Value]" 2>/dev/null
}

# NAME: vgs_aws_ec2_create_tags
# DESCRIPTION: Creates EC2 tags.
# USAGE: vgs_aws_ec2_create_tags {Resource ID} {TAGS}
# PARAMETERS:
#   1) The resource id (required)
#   2) One or more tags (Key=string,Value=string ...)
vgs_aws_ec2_create_tags(){
  local id=${1:?Must specify the resource id as the 1st argument}
  shift

  e_info "Tagging ${id}"
  aws ec2 create-tags --resources "$id" --tags "$@"
}

# NAME: vgs_aws_ec2_get_asg_instance_state
# DESCRIPTION: Gets the state of the given <EC2 instance ID> as known by the AutoScaling
# group it's a part of.
# USAGE: vgs_aws_ec2_get_asg_instance_state {EC2 instance ID}
# PARAMETERS:
#   1) The instance id
vgs_aws_ec2_get_asg_instance_state() {
  local instance_id=${1:?Must specify the instance id as the 1st argument}
  local state; state=$(aws autoscaling describe-auto-scaling-instances \
    --instance-ids "$instance_id" \
    --query "AutoScalingInstances[?InstanceId == \`$instance_id\`].LifecycleState | [0]" \
    --output text)
  if [ $? != 0 ]; then
    return 1
  else
    echo "$state"
    return 0
  fi
}

# NAME: aws_get_autoscaling_group_name
# DESCRIPTION: Returns the name of the auto scaling group this instance is a
# part of.
# USAGE: vgs_aws_ec2_get_asg_name {EC2 instance ID}
# PARAMETERS:
#   1) The instance id
vgs_aws_ec2_get_asg_name() {
  local instance_id=${1:?Must specify the instance id as the 1st argument}
  local asg_name; asg_name=$(aws autoscaling \
    describe-auto-scaling-instances \
    --instance-ids "$instance_id" \
    --output text \
    --query AutoScalingInstances[0].AutoScalingGroupName)

  if [ $? != 0 ]; then
    return 1
  else
    echo "$asg_name"
  fi

  return 0
}

# Moves the instance into the Standby state in AutoScaling group
vgs_aws_ec2_autoscaling_enter_standby(){
  local instance_id; instance_id=$(vgs_aws_ec2_get_instance_id)
  local asg_name; asg_name=$(vgs_aws_ec2_get_asg_name "$instance_id")

  e_info 'Checking if this instance has already been moved in the Standby state'
  local instance_state
  instance_state=$(vgs_aws_ec2_get_asg_instance_state "$instance_id")
  if [ $? != 0 ]; then
    e_abort 'Unable to get this instance lifecycle state.'
  fi

  if [ "$instance_state" == 'Standby' ]; then
    e_info 'Instance is already in Standby; nothing to do.'; return
  elif [ "$instance_state" == 'Pending' ]; then
    e_info 'Instance is Pending; nothing to do.'; return
  elif [ "$instance_state" == 'Pending:Wait' ]; then
    e_info 'Instance is Pending:Wait; nothing to do.'; return
  fi

  e_info "Putting instance $instance_id into Standby"
  aws autoscaling enter-standby \
    --instance-ids "$instance_id" \
    --auto-scaling-group-name "$asg_name" \
    --should-decrement-desired-capacity
  if [ $? != 0 ]; then
    e_abort "Failed to put instance $instance_id into Standby for ASG $asg_name."
  fi

  printf "Waiting for instance to reach state Standby..."
  while [ "$(vgs_aws_ec2_get_asg_instance_state "$instance_id")" != "Standby" ]; do
    printf '.' && sleep 5
  done
  e_ok ' Done.'

  return 0
}

# Attempts to move instance out of Standby and into InService.
vgs_aws_ec2_autoscaling_exit_standby(){
  local instance_id; instance_id=$(vgs_aws_ec2_get_instance_id)
  local asg_name; asg_name=$(vgs_aws_ec2_get_asg_name "$instance_id")

  e_info 'Checking if this instance has already been moved out of Standby state'
  local instance_state
  instance_state=$(vgs_aws_ec2_get_asg_instance_state "$instance_id")
  if [ $? != 0 ]; then
    e_abort 'Unable to get this instance lifecycle state.'
  fi

  if [ "$instance_state" == 'InService' ]; then
    e_info 'Instance is already in InService; nothing to do.'; return
  elif [ "$instance_state" == 'Pending' ]; then
    e_info 'Instance is Pending; nothing to do.'; return
  elif [ "$instance_state" == 'Pending:Wait' ]; then
    e_info 'Instance is Pending:Wait; nothing to do.'; return
  fi

  e_info "Moving instance $instance_id out of Standby"
  aws autoscaling exit-standby \
    --instance-ids "$instance_id" \
    --auto-scaling-group-name "$asg_name"
  if [ $? != 0 ]; then
    e_abort "Failed to put instance $instance_id back into InService for ASG $asg_name."
  fi

  printf 'Waiting for instance to reach state InService...'
  while [ "$(vgs_aws_ec2_get_asg_instance_state "$instance_id")" != "InService" ]; do
    printf '.' && sleep 5
  done
  e_ok ' Done.'

  return 0
}

# NAME: vgs_aws_ec2_get_ubuntu_official_ami_id
# DESCRIPTION: Retrieves the latest AMI ID for the official Ubuntu image.
# The region defaults to us-east-1.
# USAGE: vgs_aws_ec2_get_ubuntu_official_ami_id {Distribution} {Type} {Arch} \
#          {Virtualization}
# PARAMETERS:
#   1) Distribution code name (defaults to 'trusty')
#   2) Root device type (defaults to 'ebs-ssd')
#   3) Architecture (defaults to 'amd64')
#   4) Virtualization (defaults to 'hvm')
vgs_aws_ec2_get_ubuntu_official_ami_id() {
  local dist=${1:-trusty}
  local dtyp=${2:-ebs-ssd}
  local arch=${3:-amd64}
  local virt=${4:-hvm}
  local region=${AWS_DEFAULT_REGION:-us-east-1}

  curl -Ls "http://cloud-images.ubuntu.com/query/${dist}/server/released.current.txt" | \
    awk -v region="$region" \
        -v dist="$dist" \
        -v dtyp="$dtyp" \
        -v arch="$arch" \
        -v virt="$virt" \
    '$5 == dtyp && $6 == arch && $7 == region && $9 == virt { print $8 }'
}

# NAME: vgs_aws_ec2_get_ubuntu_base_image_id
# DESCRIPTION: Retrieves the latest AMI ID for the official Ubuntu image
# (x64 hvm ssd ebs).
# USAGE: vgs_aws_ec2_get_ubuntu_base_image_id {Code Name}
# PARAMETERS:
#   1) Distribution code name (defaults to 'xenial-16.04')
vgs_aws_ec2_get_ubuntu_base_image_id(){
  local codename=${1:-'xenial-16.04'}

  local base_image_id; base_image_id=$(aws ec2 describe-images \
      --owners 099720109477 \
      --filters \
        Name=name,Values="*ubuntu-${codename}-*" \
        Name=architecture,Values=x86_64 \
        Name=block-device-mapping.volume-type,Values=gp2 \
        Name=state,Values=available \
        Name=root-device-type,Values=ebs \
        Name=virtualization-type,Values=hvm \
      --query 'reverse(sort_by(Images, &CreationDate))[0].{ImageId: ImageId}' \
      --output text)

  if [[ "$base_image_id" =~ ^ami-.* ]]; then
    echo "$base_image_id"
  else
    e_abort 'Could not get the image id'
  fi
}

# NAME: vgs_aws_ec2_get_latest_ami_id
# DESCRIPTION: Retrieves the latest AMI ID for a specified prefix.
# USAGE: vgs_aws_ec2_get_latest_ami_id {Prefix}
# PARAMETERS:
#   1) The prefix
vgs_aws_ec2_get_latest_ami_id() {
  local prefix="${1:-}"
  local id; id=$(aws ec2 describe-images \
      --owners self \
      --filters \
        Name=name,Values="${prefix}*" \
      --query 'reverse(sort_by(Images, &CreationDate))[0].{ImageId: ImageId}' \
      --output text)

  if [[ "$id" =~ ^ami-.* ]]; then
    echo "$id"
  else
    e_abort 'Could not get the image id'
  fi
}

# NAME: vgs_aws_ec2_create_instance
# DESCRIPTION: Deletes all but the most recent image
# USAGE: vgs_aws_ec2_create_instance {Key} {Type} {User Data} {IAM Profile}
# PARAMETERS:
#   1) Key pair name (required)
#   2) The instance type (required)
#   3) The file containing the data to configure the instance (required)
#   4) The IAM instance profile (required)
vgs_aws_ec2_create_instance(){
  local key=${1:?Must specify the key name as the 1st argument}
  local instance_type=${2:?Must specify the instance type as the 2nd argument}
  local user_data_file=${3:?Must specify the user data file as the 3rd argument}
  local instance_profile=${4:-}

  local base_image_id; base_image_id=$(vgs_aws_ec2_get_ubuntu_base_image_id 'xenial-16.04')

  local instance_id; instance_id=$(aws ec2 run-instances \
    --key "$key" \
    --instance-type "$instance_type" \
    --image-id "$base_image_id" \
    --user-data "file://${user_data_file}" \
    --iam-instance-profile "Name=${instance_profile}" \
    --output text \
    --query 'Instances[*].InstanceId')
  sleep 5

  if [[ "$instance_id" =~ ^i-.* ]]; then
    echo "$instance_id"
  else
    e_abort 'Could not create the EC2 instance'
  fi
}

# NAME: vgs_aws_ec2_image_create
# DESCRIPTION: Deletes all but the most recent image
# USAGE: vgs_aws_ec2_image_create {Instance ID} {Prefix} {Description}
# PARAMETERS:
#   1) Instance ID (required)
#   1) Image prefix (defaults to 'AMI')
#   1) Image description (defaults to 'AMI')
vgs_aws_ec2_image_create(){
  local instance_id=${1:?Must specify the instance id as the 1st argument}
  local prefix=${2:-AMI}
  local description=${3:-AMI}

  local image_name; image_name="${prefix}_$(date +%Y%m%d%H%M%S)"

  local image_id; image_id=$(aws ec2 create-image \
    --instance-id "$instance_id" \
    --name "${image_name}" \
    --description "${description}" \
    --output text --query 'ImageId')
  sleep 5

  if [[ "$image_id" =~ ^ami-.* ]]; then
    echo "${image_id}"
  else
    e_abort 'Could not create the EC2 image'
  fi
}

# NAME: vgs_aws_ec2_images_purge
# DESCRIPTION: Deletes all but the most recent image.
# USAGE: vgs_aws_ec2_images_purge {Image name}
# PARAMETERS:
#   1) Image name (required). Can contain wildcard (Ex: My_AMI_*)
#   2) A list of image ids to keep (optional) (Ex: 'ami-123 ami-456')
vgs_aws_ec2_images_purge(){
  local image_name=${1:?Must specify the image name as the 1st argument}
  local keep=${2:-}
  if [ -z "$1" ] ; then e_abort "USAGE: ${FUNCNAME[0]} {Image name}"; fi

  newest_image=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=${image_name}" \
    --output text \
    --query 'reverse(sort_by(Images, &CreationDate))[0].{ImageId: ImageId}')

  all_images=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=${image_name}" \
    --output text \
    --query 'Images[*].{ID:ImageId}')

  for image_id in $all_images; do
    [[ "$newest_image" == "$image_id" ]] && continue
    [[ "$keep" =~ $image_id ]] && continue
    snapshot_id=$(aws ec2 describe-images \
      --image-ids "$image_id" \
      --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' \
      --output text)
    e_info "Deregister image ${image_id}"
    aws ec2 deregister-image --image-id "$image_id"
    e_info "Delete snapshot ${snapshot_id}"
    aws ec2 delete-snapshot --snapshot-id "${snapshot_id}"
  done
}

# Returns the ELB to which the instance is registered.
vgs_aws_ec2_get_elb_name() {
  local instance_id; instance_id=$(vgs_aws_ec2_get_instance_id)
  if output=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?contains(Instances[].InstanceId, \`${instance_id}\`)].LoadBalancerName" --output text); then
    echo "$output"
  else
    return $?
  fi
}

# Returns the Elastic Load Balancer health check configuration
vgs_aws_ec2_elb_configure_health_check() {
  local elb; elb=$(vgs_aws_ec2_get_elb_name)
  if output=$(aws elb describe-load-balancers --load-balancer-names "$elb" --query 'LoadBalancerDescriptions[].HealthCheck | [0]'); then
    echo "$output"
  else
    return $?
  fi
}

# NAME: aws_elb_configure_health_check
# DESCRIPTION: Modifies the Elastic Load Balancer' health check configuration
# USAGE: aws_elb_configure_health_check {Config}
# PARAMETERS:
#   1) Configuration (required)
#      Ex: Target=HTTP:80/,Interval=10,UnhealthyThreshold=5,HealthyThreshold=2,Timeout=5
vgs_aws_ec2_elb_configure_health_check() {
  local elb; elb=$(vgs_aws_ec2_get_elb_name)
  if output=$(aws elb configure-health-check --load-balancer-name "$elb" --health-check "$1"); then
    echo "$output"
  else
    return $?
  fi
}

# NAME: vgs_aws_ec2_run_command
# DESCRIPTION: Sends a command to instances
# USAGE: vgs_aws_ec2_run_command {Filter} {Parameters} {Comment} {TimeOut}
# PARAMETERS:
#   1) Filter the instances (required)
#      See --filters section at http://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instances.html
#      Ex: Name=tag:Group,Values=MyGroupName
#   2) Parameters (required)
#      See --parameters section at http://docs.aws.amazon.com/cli/latest/reference/ssm/send-command.html
#   3) User-specified information about the command, such as a brief description
#      of what the command should do (required)
#   4) Timeout. If this time is reached and the command has not already started
#      executing, it will not execute. (required)
vgs_aws_ec2_run_command(){
  local filter=${1:?Must specify the filter as the 1st argument}
  local params=${2:?Must specify the parameters as the 2nd argument}
  local comment=${3:?Must specify the comment as the 3rd argument}
  local timeout=${4:?Must specify the timeout as the 4th argument}

  ids=$(aws ec2 describe-instances \
    --filter "$filter" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

  command_id=$(aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$ids" \
    --parameters "$params" \
    --comment "$comment" \
    --timeout-seconds "$timeout" \
    --query 'Command.CommandId' \
    --output text)

  # Wait until at least 1 invocation returns succes
  until [[ $(aws ssm list-commands --region us-east-1 --command-id "$command_id" --query 'Commands[].Status' --output text) =~ 'Success' ]]; do sleep 1; done
}
