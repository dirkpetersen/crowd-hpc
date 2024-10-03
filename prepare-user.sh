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

# Function to detect if we are running on Redhat or Debian family
check_os_family() {
  local OS_FAMILY
  if ! [[ -f /etc/os-release ]]; then
    echo "Unsupported operating system" >&2
    exit 1
  fi
  . /etc/os-release
  if [[ " ${ID_LIKE} " =~ " fedora " ]]; then
    OS_FAMILY="redhat" # rhel centos fedora rocky alma
  elif [[ " ${ID_LIKE} " =~ " debian " ]]; then
    OS_FAMILY="debian" # ubuntu debian
  else
    echo "Unsupported operating system: ${ID}" >&2
    exit 1
  fi
  echo ${OS_FAMILY}
}

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
  usermod -aG libvirt,kvm ${NEWUSER}

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
  echo -e "\nEnter: sudo su - ${NEWUSER}"
}

# Main execution
OS_FAMILY=$(check_os_family)
create_or_modify_user