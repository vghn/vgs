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

# Updates the VGS library
vgs_self_update(){
  local vgs_path vgs_url update_script

  vgs_url='https://s3.amazonaws.com/vghn-vgs/vgs.tgz'
  update_script="${VGS_TMP}/update.sh"

  if [[ $EUID == 0 ]]; then
    vgs_path='/opt/vgs'
  else
    vgs_path="${HOME}/vgs"
  fi

  cat > "$update_script" << EOS
#!/usr/bin/env bash
echo 'Updating VGS Library'
mkdir -p "$vgs_path"
wget -qO- "$vgs_url" | tar xz -C "$vgs_path"
echo 'VGS Library updated. Make sure you reload it.'
echo ". ${vgs_path}/load"
EOS

  exec /bin/bash "$update_script"
}
