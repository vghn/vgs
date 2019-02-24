#!/usr/bin/env bash
# Miscellaneous Functions

# Notify Slack Webhook. Requires a SLACK_WEBHOOK environment variable
# ARGUMENTS:
#   1) The channel name (required)
#   2) The user name (required)
#   3) The text message (required)
vgs_notify_slack(){
  local channel username text
  channel="${1:?Must specify the channel name as the 1st argument}"
  username="${2:?Must specify the user name as the 2nd argument}"
  text="${3:?Must specify the message as the 3rd argument}"

  # Colors: red: ce0814, green: 3ca553, blue: 4484c2

  printf "Notify slack... "
  curl -s -X POST --data-urlencode "payload={\"channel\": \"#${channel}\", \"username\": \"${username}\", \"text\": \"${text}\", \"icon_emoji\": \":taurus:\"}" "$SLACK_WEBHOOK"
}

# Traps exit and notify Slack.
# GLOBALS:
# - SLACK_CHANNEL
# - SLACK_USER
# - SLACK_WEBHOOK
# ARGUMENTS:
#   1) The exit status (required)
#   2) The command title (optional)
vgs_slack_trap(){
  local exit_code cmd info title color text
  exit_code=${1:-0}
  cmd=${2:-Command}
  info="$(hostname) @ $(TZ=US/Central date)"

  if [[ $exit_code == 0 ]]; then
    title='SUCCESS'
    color='#3ca553'
  else
    title='FAILED'
    color='#ce0814'
  fi
  text="${cmd} exited with ${exit_code} on ${info}"

  if [[ -n "$SLACK_CHANNEL" ]] && \
    [[ -n "$SLACK_USER" ]] && \
    [[ -n "$SLACK_WEBHOOK" ]]
  then
    printf 'Sending Slack message... '
    curl -s -X POST --data-urlencode "payload={\"channel\": \"#${SLACK_CHANNEL}\", \"username\": \"${SLACK_USER}\", \"icon_emoji\": \":taurus:\", \"attachments\": [{\"title\": \"${title}\", \"text\": \"${text}\", \"color\": \"${color}\"}]}" "${SLACK_WEBHOOK}" || echo 'failed'
    echo
  fi

  echo "$title: $text"; exit "$exit_code"
}

# Encrypts a file.
# ARGUMENTS:
#   1) The encryption key (required)
#   2) The decrypted file (required)
#   3) The encrypted file (required)
vgs_encrypt(){
  local key in out
  key="${1:?Must specify the encryption key as the 1st argument}"
  in="${2:?Must specify the decrypted file as the 2nd argument}"
  out="${3:?Must specify the encrypted file as the 3rd argument}"

  # Start a subshell and ensure it is not run in debug mode
  ( set +e; openssl aes-256-cbc -k "$key" -in "$in" -out "$out" )
}

# Encrypts a file.
# ARGUMENTS:
#   1) The encryption key (required)
#   2) The encrypted file (required)
#   3) The decrypted file (required)
vgs_decrypt(){
  local key in out
  key="${1:?Must specify the encryption key as the 1st argument}"
  in="${2:?Must specify the decrypted file as the 2nd argument}"
  out="${3:?Must specify the encrypted file as the 3rd argument}"

  # Start a subshell and ensure it is not run in debug mode
  ( set +e; openssl aes-256-cbc -k "$key" -in "$in" -out "$out" -d )
}

# Parses an YAML file.
# Thanks: https://gist.github.com/pkuczynski/8665367
# ARGUMENTS:
#   1) The yaml file (required)
#   2) The prefix (optional)
vgs_parse_yaml() {
   local prefix=${2:-}
   local s w fs
   s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\\($s\\)\\($w\\)$s:$s\"\\(.*\\)\"$s\$|\\1$fs\\2$fs\\3|p" \
        -e "s|^\\($s\\)\\($w\\)$s:$s\\(.*\\)$s\$|\\1$fs\\2$fs\\3|p"  "${1:?}" |
   awk -F"$fs" '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'"$prefix"'", vn, $2, $3);
      }
   }'
}
