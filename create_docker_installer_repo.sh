#!/usr/bin/env bash

# wget https://raw.githubusercontent.com/jscheunemann/unifi-scripts/main/create_packages_tarball_debian_10_amd64.sh

set -e

PACKAGER_DIR=$(pwd)/docker_packages


GPG_CONFIG_FILE="$HOME/gpg-config"
GPG_PASSWORD_FILE=$HOME/.gpg_password

[ ! -f $GPG_PASSWORD_FILE ] && GPG_KEY_EXITS=1
[ ! -z $GPG_KEY_EXITS ] && date +%s | sha256sum | base64 | head -c 32 > $GPG_PASSWORD_FILE

cat > $GPG_CONFIG_FILE <<- EOF
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: Jason Scheunemann
Name-Email: jason.scheunemann@gmail.com
Expire-Date: 0
EOF



sudo apt update

[ ! -z $GPG_KEY_EXITS ] && gpg --batch --passphrase-file $GPG_PASSWORD_FILE --pinentry-mode loopback --gen-key $GPG_CONFIG_FILE
mkdir -p ${PACKAGER_DIR}
cd ${PACKAGER_DIR}
~/unifi-scripts/get-deb-packages-with-deps.sh apt-transport-https
~/unifi-scripts/get-deb-packages-with-deps.sh ca-certificates
~/unifi-scripts/get-deb-packages-with-deps.sh wget
~/unifi-scripts/get-deb-packages-with-deps.sh software-properties-common
~/unifi-scripts/get-deb-packages-with-deps.sh multiarch-support
~/unifi-scripts/get-deb-packages-with-deps.sh gpgconf
~/unifi-scripts/get-deb-packages-with-deps.sh libassuan0
~/unifi-scripts/get-deb-packages-with-deps.sh gpg
~/unifi-scripts/get-deb-packages-with-deps.sh libnpth0
~/unifi-scripts/get-deb-packages-with-deps.sh libksba8
~/unifi-scripts/get-deb-packages-with-deps.sh dirmngr
~/unifi-scripts/get-deb-packages-with-deps.sh gnupg-l10n
~/unifi-scripts/get-deb-packages-with-deps.sh gnupg-utils
~/unifi-scripts/get-deb-packages-with-deps.sh pinentry-curses
~/unifi-scripts/get-deb-packages-with-deps.sh gpg-agent
~/unifi-scripts/get-deb-packages-with-deps.sh gpg-wks-client
~/unifi-scripts/get-deb-packages-with-deps.sh gpg-wks-server
~/unifi-scripts/get-deb-packages-with-deps.sh gpgsm
~/unifi-scripts/get-deb-packages-with-deps.sh gnupg
~/unifi-scripts/get-deb-packages-with-deps.sh gnupg2
~/unifi-scripts/get-deb-packages-with-deps.sh adoptopenjdk-8-hotspot
~/unifi-scripts/get-deb-packages-with-deps.sh unifi
~/unifi-scripts/get-deb-packages-with-deps.sh sudo
gpg --batch --passphrase-file $GPG_PASSWORD_FILE --pinentry-mode loopback --output public.key --armor --export jason.scheunemann@gmail.com
~/unifi-scripts/deb-repo.sh
cd -
tar czvf ${PACKAGER_DIR}.tgz ${PACKAGER_DIR}
cat ~/docker-scripts/create_unifi_installer.sh ${PACKAGER_DIR}.tgz > docker_installer.sh
