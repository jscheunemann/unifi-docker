#!/usr/bin/env bash

set -e

# Script info
SCRIPT_FULL_PATH="$(realpath "${0}")"
SCRIPT_NAME="$(basename "${SCRIPT_FULL_PATH%.*}")"
SCRIPT_VERSION="1.0"

# Misc commands
SET_RED_PROMPT="$(tput setaf 1)"
SET_GREEN_PROMPT="$(tput setaf 2)"
SET_YELLOW_PROMPT="tput setaf 3"
SET_NORMAL_PROMPT="tput setaf 9"
RESET_PROMPT="$(tput init)"
BR="echo"

# Misc variables
declare -i EXIT_CODE
EXIT_CODE=0
ARCH=$(dpkg --print-architecture | awk -F- '{ print $NF }')
RUN_AS_ROOT_MESSAGE="${SCRIPT_NAME} must be run as root."
ORIG_USER="$(who am i | awk '{print $1}')"
LOG_FILE="$(pwd)/${SCRIPT_NAME}.log"


die() {
    declare -i ERR_CODE
    ERR_CODE=${1}

    [ "${ERR_CODE}" == "" ] && exit 1 || exit "${ERR_CODE}"
}

# Ensure the script is ran as root
if [[ ${EUID} -ne 0 ]]; then
   ${SET_YELLOW_PROMPT}
   echo "${RUN_AS_ROOT_MESSAGE}"

   die 1
fi

function catch() {
    ${SET_NORMAL_PROMPT}
    rm -f "/var/tmp/${SCRIPT_NAME}.lock"

    die ${EXIT_CODE}
}

function update_apt() {
    echo "- Attempting to update apt" | tee -a ${LOG_FILE}
    apt update >> ${LOG_FILE} 2>&1
    [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
    printf "${RESULT} Apt successfully updated\n" | tee -a ${LOG_FILE}
}

function upgrade_all_apt_packages() {
    PACKAGES_NEED_UPGRADE=$(apt list --upgradeable 2>&1 | sed -e '1,/Listing.../d' | wc -l)

    [ ${PACKAGES_NEED_UPGRADE} -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
    printf "${RESULT} All packages up-to-date\n" | tee -a ${LOG_FILE}

    if [ ! ${PACKAGES_NEED_UPGRADE} -eq 0 ]; then
        echo "- Attempting to upgrade all packages" | tee -a ${LOG_FILE}
        apt upgrade -y >> ${LOG_FILE} 2>&1
        [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
        printf "${RESULT} Upgraded all packages\n" | tee -a ${LOG_FILE}
    fi
}

function install_package() {
    PACKAGE=${1}
    INSTALLED=0

    [ $(apt -qq list ${PACKAGE} 2>&1 | grep -c '\[installed') -eq 1 ] && INSTALLED=1
    [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
    printf "${RESULT} Required package ${PACKAGE} already installed\n" | tee -a ${LOG_FILE}

    if [ ${INSTALLED} -eq 0 ]; then
        echo "- Attempting to install ${PACKAGE}" | tee -a ${LOG_FILE}
        apt install -y ${PACKAGE} >> ${LOG_FILE} 2>&1
        [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
        printf "${RESULT} Package ${PACKAGE} successfully installed\n" | tee -a ${LOG_FILE}
    fi
}

function remove_unwanted_programs() {
    REMOVE=0

    [ $(apt -qq list ${PACKAGE} 2>&1 | grep -c '\[installed\]') -eq 1 ] && REMOVE=1
    [ ${REMOVE} -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
    printf "${RESULT} Ensure package ${PACKAGE} is not installed\n" | tee -a ${LOG_FILE}


    if [ ${REMOVE} -eq 1 ]; then
        echo "- Attempting to remove ${PACKAGE}" | tee -a ${LOG_FILE}
        apt remove -y ${PACKAGE} >> ${LOG_FILE} 2>&1
        [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
        printf "${RESULT} Package ${PACKAGE} successfully removed\n" | tee -a ${LOG_FILE}
    fi
}

function add_user_to_docker() {
    USER_ADDED_TO_DOCKER=0

    [ $(id ${ORIG_USER} | grep -cw docker) -eq 1 ] && USER_ADDED_TO_DOCKER=1

    [ ${USER_ADDED_TO_DOCKER} -eq 1 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
    printf "${RESULT} User ${ORIG_USER} already added to docker group\n" | tee -a ${LOG_FILE}

    if [ ${USER_ADDED_TO_DOCKER} -eq 0 ]; then
        echo "- Attempting to add ${ORIG_USER} to the docker group" | tee -a ${LOG_FILE}
        usermod -aG docker ${ORIG_USER} >> ${LOG_FILE} 2>&1
        [ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
        printf "${RESULT} Added ${ORIG_USER} to the docker group\n" | tee -a ${LOG_FILE}
    fi
}

# Create lock to ensure only one instance runs at a time, limit resource concurrency issues
exec 100>/var/tmp/"${SCRIPT_NAME}".lock || die 255
if ! flock -n 100; then
    ${SET_YELLOW_PROMPT} # Set text yellow text
    echo -e "${INSTANCE_ALREADY_RUNNING}"
    ${SET_NORMAL_PROMPT} # Set prompt to normal
    die 255
fi

# Cleanup on exit. In order; blank line, set text normal, delete lock file, exit abnormally
trap 'catch' SIGINT SIGTERM ERR EXIT

: > ${LOG_FILE}

# Update apt and upgrade all packages
update_apt
upgrade_all_apt_packages

# Remove packages that interfere with Docker
UNWANTED_PACKAGES="docker docker-engine docker.io conatainerd runc"
for PACKAGE in ${UNWANTED_PACKAGES}; do
    remove_unwanted_programs ${PACKAGE}
done

# Install pre-requisites
REQUIRED_PACKAGES="apt-transport-https ca-certificates curl gnupg lsb-release vim git"
for PACKAGE in ${REQUIRED_PACKAGES}; do
    install_package ${PACKAGE}
done

# Install Docker signing key
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> ${LOG_FILE} 2>&1
[ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
printf "${RESULT} Installed the Docker repo key\n" | tee -a ${LOG_FILE}

# Install Docker repo
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list >> ${LOG_FILE} 2>&1
[ "${?}" -eq 0 ] && RESULT="${SET_GREEN_PROMPT}✔${RESET_PROMPT}" || RESULT="${SET_RED_PROMPT}✘${RESET_PROMPT}"
printf "${RESULT} Added the Docker repo to /etc/apt/sources.list.d/docker.list\n" | tee -a ${LOG_FILE}

# Update apt and install Docker packages
update_apt
REQUIRED_PACKAGES="docker-ce docker-ce-cli containerd.io docker-compose"
for PACKAGE in ${REQUIRED_PACKAGES}; do
    install_package ${PACKAGE}
done

add_user_to_docker
