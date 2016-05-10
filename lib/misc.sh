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

  # red:   ce0814
  # green: 3ca553
  # blue:  4484c2

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

# NAME: vgs_parse_yaml
# DESCRIPTION: Parses an YAML file.
#              Credits: https://gist.github.com/pkuczynski/8665367
# USAGE: eval $(vgs_parse_yaml {File} {Prefix})
# PARAMETERS:
#   1) The yaml file (required)
#   2) The prefix (optional)
vgs_parse_yaml() {
   local prefix=${2:-}
   local s w fs
   s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  "${1:?}" |
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
