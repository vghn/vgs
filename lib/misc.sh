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
