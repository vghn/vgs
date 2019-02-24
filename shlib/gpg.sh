#!/usr/bin/env bash
# GPG Functions

# Encrypt .env file
encrypt_env(){
  if [[ -s "${APPDIR}/.env" ]]; then
    e_info 'Encrypt .env'
    gpg --batch --yes --passphrase "$( echo "$ENCRYPT_KEY" | base64 --decode --ignore-garbage )" --cipher-algo AES256 --s2k-digest-algo SHA512 --symmetric --output "${APPDIR}/.env.gpg" "${APPDIR}/.env"
  fi
}

# Decrypt .env file
decrypt_env(){
  if [[ ! -s "${APPDIR}/.env" ]]; then
    e_info 'Decrypt .env'
    gpg --batch --yes --passphrase "$( echo "$ENCRYPT_KEY" | base64 --decode --ignore-garbage )" --decrypt --output "${APPDIR}/.env" "${APPDIR}/.env.gpg"
  fi
}
