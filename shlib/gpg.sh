#!/usr/bin/env bash
# GPG Functions

# Encrypt .env file
encrypt_env(){
  if [[ -s "${APPDIR}/.env" ]]; then
    e_info 'Encrypt .env'
    ( echo "$ENCRYPT_KEY" | base64 --decode --ignore-garbage ) | \
      gpg --batch --yes --symmetric --passphrase-fd 0 --cipher-algo AES256 --s2k-digest-algo SHA512 --output "${APPDIR}/.env.gpg" "${APPDIR}/.env"
  fi
}

# Decrypt .env file
decrypt_env(){
  if [[ ! -s "${APPDIR}/.env" ]]; then
    e_info 'Decrypt .env'
    ( echo "$ENCRYPT_KEY" | base64 --decode --ignore-garbage ) | \
      gpg --batch --yes --decrypt --passphrase-fd 0 --output "${APPDIR}/.env" "${APPDIR}/.env.gpg"
  fi
}
