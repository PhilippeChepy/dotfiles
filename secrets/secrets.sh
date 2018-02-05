#!/usr/bin/env zsh

cd -- "$(dirname "$0")"

function input_password {
  echo "${fg[blue]}$2${reset_color}"

  echo -n Password:
  read -s password
  echo

  if [ "$1" = "e" ]; then
    echo -n Confirmation:
    read -s password_confirmation
    echo

    if [ "$password" != "$password_confirmation" ]; then
      echo "Password mismatch"
      exit 1
    fi
  fi
}

function secrets_cipher {
  input_password e "➜ Cipher secrets archive"
  secrets=$(ls -d */ 2> /dev/null | cut -f1 -d'/' | tr '\n' ' ')

  sh -c "tar -cj $secrets | openssl enc -aes-256-cbc -salt -e -k $password > ~/Desktop/secrets.aes"
}

function secrets_uncipher {
  input_password d "➜ Decipher secrets archive"

  openssl enc -aes-256-cbc -d -k $password < ~/Desktop/secrets.aes | tar -x $secret
}

function secrets_clean {
  rm -rf ansible-vault
  rm -rf gpg
  rm -rf ssh
}

function secrets_backup {
  echo "${fg[blue]}➜ Ansible Vault passwords from ~/.ansible-passwords${reset_color}"
  mkdir -p ansible-vault
  cp ~/.ansible-passwords/* ansible-vault/
  echo

  mkdir -p gpg
  IFS=$'\n'
  for line in $(gpg --list-secret-keys --with-colons 2> /dev/null |grep fpr |cut -d: -f10)
  do
    echo "${fg[blue]}➜ GPG Key $line"
    echo "gpg --export-secret-keys -a $line"
    gpg --export-secret-keys -a $line > gpg/$line.asc 2> /dev/null
  done
  echo

  echo "${fg[blue]}➜ SSH Keys from '~/.ssh/id_*'${reset_color}"
  mkdir -p ssh
  cp ~/.ssh/id_* ssh/
  echo

  secrets_cipher
  secrets_clean
}

function secrets_restore {
  secrets_uncipher

  mkdir -p ~/.ansible-passwords

  # Ansible
  cd ansible-vault
  for passw_file in $(ls * | cut -f1 -d'/')
  do
    echo "${fg[blue]}➜ Ansible Vault password file '$passw_file'${reset_color}"
    cp $passw_file ~/.ansible-passwords/$passw_file
  done
  cd - > /dev/null

  echo

  # GPG
  cd gpg
  for gpg_key_file in $(ls * | cut -f1 -d'/')
  do
    echo "${fg[blue]}➜ GPG Key from '$gpg_key_file'${reset_color}"
    gpg --allow-secret-key-import --import $gpg_key_file 2> /dev/null
  done
  cd - > /dev/null

  echo

  # SSH
  cd ssh
  for ssh_key_file in $(ls * | cut -f1 -d'/')
  do
    echo "${fg[blue]}➜ SSH Key from '$ssh_key_file'${reset_color}"
    cp $ssh_key_file ~/.ssh/$ssh_key_file
  done
  cd - > /dev/null
  secrets_clean
}

case $1 in
backup)
  secrets_backup
  ;;
restore)
  secrets_restore
  ;;
*)
  echo "Usage: $(basename $0) (backup|restore)"
  echo "$(basename $0) allow to load / restore secrets from/to an archive (~/Desktop/secrets.aes)"
  ;;
esac
