#!/usr/bin/env bash
# Miscellaneous Functions

# NAME: vgs_notify_slack
# DESCRIPTION: Notify Slack Webhook. Requires a SLACK_WEBHOOK environment variable
# USAGE: vgs_notify_slack {Channel} {Username} {Text}
# PARAMETERS:
#   1) The channel name (required)
#   2) The user name (required)
#   3) The text message (required)
vgs_notify_slack(){
  local channel="${1:?}"
  local username="${2:?}"
  local text="${3:?}"
  printf "Notify slack... "
  curl -s -X POST --data-urlencode "payload={\"channel\": \"#${channel}\", \"username\": \"${username}\", \"text\": \"${text}\", \"icon_emoji\": \":taurus:\"}" "$SLACK_WEBHOOK"
}

# Read YAML file from Bash script
# Credits: https://gist.github.com/pkuczynski/8665367
# USAGE:
# source common.sh
#   . common.sh
# read yaml file
#   eval $(parse_yaml config.yml "config_")
# access yaml content
#   echo $config_development_database
# YAML content
#   development:
#     database: my_database
vgs_parse_yaml() {
  local prefix=$2
  local s w fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_]*'
  fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  "$1" |
    -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
    }'
}
