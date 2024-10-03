#!/bin/bash

# run this for each user who would like to manage their own VMs

# Constants
NEWUSER=${1}  # The username to be created/tweaked
SHELL_BIN="/bin/bash"

if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

if [[ -z ${NEWUSER} ]]; then
  echo "Please enter a username as argument"
  exit 1 
fi

# Load support functions from the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/support-functions.sh"

OS_FAMILY=$(check_os_family)

# Function to create or modify the user
create_or_modify_user() {
  if id "${NEWUSER}" &>/dev/null; then
    echo "User ${NEWUSER} already exists."
  else
    echo "Creating user ${NEWUSER}..."
    useradd -rm --shell ${SHELL_BIN} ${NEWUSER}
  fi

  echo "Enabling linger for ${NEWUSER}..."
  loginctl enable-linger ${NEWUSER}

  if [[ "${OS_FAMILY}" == "debian" ]]; then
    echo "Adding user ${NEWUSER} to libvirt and kvm groups on Debian/Ubuntu type OS..."
    usermod -aG libvirt,kvm ${NEWUSER}
  elif [[ "${OS_FAMILY}" == "redhat" ]]; then 
    echo "Adding user ${NEWUSER} to libvirtd and kvm groups on Redhat type OS..."
    usermod -aG libvirtd,kvm ${NEWUSER}
  fi

  echo "Configure environment for ${NEWUSER} ..."
  su - ${NEWUSER} -c "bash -c '
    if [[ "'${OS_FAMILY}'" == "redhat" ]]; then 
      python3 -m pip install virtualbmc
    fi
    echo \"export DBUS_SESSION_BUS_ADDRESS=\${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/\$(id -u)/bus}\" >> ~/.bashrc
    echo \"export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}\" >> ~/.bashrc
    echo \"alias virsh=\\\"virsh --connect qemu:///session\\\"\" >> ~/.bashrc
    source ~/.bashrc
  '"
  echo "Enter: sudo su - ${NEWUSER}"
}

# Main execution
create_or_modify_user