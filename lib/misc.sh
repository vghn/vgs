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
  local channel username text
  channel="${1:?}"
  username="${2:?}"
  text="${3:?}"
  printf "Notify slack... "
  curl -s -X POST --data-urlencode "payload={\"channel\": \"#${channel}\", \"username\": \"${username}\", \"text\": \"${text}\", \"icon_emoji\": \":taurus:\"}" "$SLACK_WEBHOOK"
}

# NAME: vgs_encrypt
# DESCRIPTION: Encrypts a file.
# USAGE: vgs_encrypt {Key} {Source} {Destination}
# PARAMETERS:
#   1) The encryption key (required)
#   2) The decrypted file (required)
#   3) The encrypted file (required)
vgs_encrypt(){
  local key in out
  key="${1:?}"
  in="${2:?}"
  out="${3:?}"

  # Start a subshell and ensure it is not run in debug mode
  ( set +e; openssl aes-256-cbc -k "$key" -in "$in" -out "$out" )
}

# NAME: vgs_decrypt
# DESCRIPTION: Encrypts a file.
# USAGE: vgs_decrypt {Key} {Source} {Destination}
# PARAMETERS:
#   1) The encryption key (required)
#   2) The encrypted file (required)
#   3) The decrypted file (required)
vgs_decrypt(){
  local key in out
  key="${1:?}"
  in="${2:?}"
  out="${3:?}"

  # Start a subshell and ensure it is not run in debug mode
  ( set +e; openssl aes-256-cbc -k "$key" -in "$in" -out "$out" -d )
}
