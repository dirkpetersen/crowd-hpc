#!/bin/bash

# run this for each user who would like to manage their own VMs

# Constants
NEWUSER=${1}  # The username to be created/tweaked
SHELL_BIN="/bin/bash"

if [[ -z ${NEWUSER} ]]; then
  echo "Please enter a username as argument"
  exit 1 
fi

# Check if the script is running on Ubuntu or RHEL
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS_NAME=${ID}
else
  echo "Unsupported operating system"
  exit 1
fi

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

  if [[ "${OS_NAME}" == "ubuntu" || "${OS_NAME}" == "debian" ]]; then
    echo "Adding user ${NEWUSER} to libvirt and kvm groups on Debian/Ubuntu..."
    usermod -aG libvirt,kvm ${NEWUSER}
  elif [[ "${OS_NAME}" == "rhel" || "${OS_NAME}" == "centos" || "${OS_NAME}" == "fedora" ]]; then
    echo "Adding user ${NEWUSER} to libvirtd and kvm groups on Redhat..."
    usermod -aG libvirtd,kvm ${NEWUSER}
  else
    echo "Unsupported OS: ${OS_NAME}"
    exit 1
  fi

  echo "Switching to user ${NEWUSER} to configure environment..."
  su - ${NEWUSER} -c "bash -c '
    echo \"export DBUS_SESSION_BUS_ADDRESS=\${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/\$(id -u)/bus}\" >> ~/.bashrc
    echo \"export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}\" >> ~/.bashrc
    echo \"alias virsh=\\\"virsh --connect qemu:///session\\\"\" >> ~/.bashrc
    source ~/.bashrc
  '"
  echo "Enter: sudo su - ${NEWUSER}"
}

# Main execution
create_or_modify_user
