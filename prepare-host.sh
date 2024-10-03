#!/bin/bash

# Run this to prepare the host/hypervisor that will run all cluster VMs 

# Ensure the script is run as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

if command -v docker &>/dev/null; then
  echo "Docker appears to be installed, please remove docker from this machine as it's network might interfere with KVM"
  exit 1
fi

# Constants which can be overwritten by environment vars
DEBIAN_PKG="${DEBIAN_PKG:-qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virtinst virtualbmc}"
REDHAT_PKG="${REDHAT_PKG:-qemu-kvm libvirt virt-install bridge-utils python3-pip libcap-ng-utils}"
NETWORK_BRIDGES="${NETWORK_BRIDGES:-default:virbr0 pxe:virbr1 ipmi:virbr2 storage:virbr3}"

install_packages() {
  local packages=()
  local failed_packages=()
  local install_command
  local install_output

  # Process arguments or use default package lists
  if [ $# -eq 0 ]; then
    if [ -f "/usr/bin/dnf" ] && [ -n "${REDHAT_PKG}" ]; then
      IFS=' ' read -ra packages <<< "${REDHAT_PKG}"
    elif [ -f "/usr/bin/apt" ] && [ -n "${DEBIAN_PKG}" ]; then
      IFS=' ' read -ra packages <<< "${DEBIAN_PKG}"
    else
      echo "No packages specified and no default package list available"
      return 1
    fi
  else
    for arg in "$@"; do
      IFS=' ' read -ra pkg_list <<< "$arg"
      packages+=("${pkg_list[@]}")
    done
  fi
  # Check if packages array is empty
  if [ ${#packages[@]} -eq 0 ]; then
    echo "No packages to install"
    return 1
  fi
  if [ -f "/usr/bin/dnf" ]; then
    install_command="dnf install -y"
    epeloutput=$($install_command "epel-release" 2>&1)
    install_output=$($install_command "${packages[@]}" 2>&1 | tee /dev/tty)
    # Parse dnf output for failed packages (compatible with Amazon Linux)
    while IFS= read -r line; do
      if [[ $line == "No match for argument"* ]]; then
        failed_packages+=($(echo $line | awk '{print $NF}'))
      fi
    done <<< "$install_output"
  elif [ -f "/usr/bin/apt" ]; then
    sudo apt update
    install_command="DEBIAN_FRONTEND=noninteractive apt install -y"
    install_output=$($install_command "${packages[@]}" 2>&1 | tee /dev/tty)
    # Parse apt output for failed packages
    while IFS= read -r line; do
      if [[ $line == *"Unable to locate package"* ]]; then
        failed_packages+=($(echo $line | awk '{print $NF}'))
      fi
    done <<< "$install_output"
  else
    echo "Error: Neither /usr/bin/dnf nor /usr/bin/apt found"
    return 1
  fi
  if [ ${#failed_packages[@]} -eq 0 ]; then
    echo "All packages were installed successfully"
    return 0
  else
    echo "The following packages failed to install: ${failed_packages[*]}"
    return 1
  fi
}

# Ensure libvirtd service is enabled and started
function manage_libvirtd {
  echo "Enabling and (re-)starting libvirtd service..."
  systemctl enable libvirtd.service
  systemctl restart libvirtd.service
}

# Define network from XML template
function define_network {
  local network_name=$1
  local bridge_name=$2
  local network_xml="/tmp/${network_name}.xml"

  echo "Attempting to define network ${network_name} with bridge ${bridge_name}..."

  if [[ ${network_name} == "default" && -f /usr/share/libvirt/networks/default.xml ]]; then
    virsh net-define /usr/share/libvirt/networks/default.xml
  else
    # Create XML template for custom network
    cat <<EOF > ${network_xml}
<network>
  <name>${network_name}</name>
  <bridge name='${bridge_name}'/>
</network>
EOF
    virsh net-define ${network_xml}
    rm -f ${network_xml} # Cleanup temporary file
  fi

  virsh net-autostart ${network_name}
  virsh net-start ${network_name}
}

# Check if a bridge exists and whether it belongs to a different network
function check_bridge_exists {
  local proposed_network=$1
  local bridge=$2
  YELLOW='\033[1;33m'
  NC='\033[0m'  # No Color (reset to default)

  ip link show "${bridge}" &> /dev/null
  if [[ $? -eq 0 ]]; then
    echo "Bridge ${bridge} already exists."
    
    # Find if the bridge is associated with an existing network
    local existing_network=""
    for net in $(virsh net-list --all --name); do
      if virsh net-dumpxml ${net} | grep -q "<bridge name='${bridge}'"; then
        existing_network=${net}
        break
      fi
    done

    if [[ -n ${existing_network} ]]; then
      echo "Bridge ${bridge} is currently associated with network '${existing_network}'."
      echo -e "To delete it, use the following commands:"
      echo -e "${YELLOW}  sudo virsh net-destroy ${existing_network} && sudo virsh net-undefine ${existing_network}${NC}"
    else
      echo "No network is associated with this bridge."
    fi

    # Avoid redefining the network if the bridge is in use
    if [[ ${existing_network} != ${proposed_network} ]]; then
      echo "Skipping definition of network ${proposed_network} as bridge ${bridge} is already in use by network '${existing_network}'."
      return 1  # Return non-zero to indicate skip
    fi
  fi
  return 0  # Return zero to indicate success
}

# Ensure /etc/qemu/bridge.conf exists with correct permissions and ownership
function configure_qemu_bridge_helper {
  # Create the directory if it doesn't exist
  if [[ ! -d /etc/qemu ]]; then
    mkdir -p /etc/qemu
  fi

  # Create or update the bridge.conf file
  if [[ ! -f /etc/qemu/bridge.conf ]]; then
    echo "Creating /etc/qemu/bridge.conf..."
    touch /etc/qemu/bridge.conf
  fi

  # Clear the bridge.conf file and add the necessary 'allow' entries
  > /etc/qemu/bridge.conf
  for network_bridge in ${NETWORK_BRIDGES}; do
    IFS=':' read -r network bridge <<< "${network_bridge}"
    echo "allow ${bridge}" >> /etc/qemu/bridge.conf
  done

  # Set the correct ownership and permissions
  chown root:root /etc/qemu/bridge.conf
  chmod 644 /etc/qemu/bridge.conf

  echo "/etc/qemu/bridge.conf has been configured."

  # is this needed ? https://bugs.gentoo.org/677152 (filecap in libcap-ng-utils)
  #filecap qemu-bridge-helper net_admin

  # Set setuid on qemu-bridge-helper
  echo "Setting setuid on qemu-bridge-helper ..."  

  if [[ -f "/usr/bin/dnf" ]]; then
    chmod u+s "/usr/libexec/qemu-bridge-helper"
  elif  [[ -f "/usr/bin/apt" ]]; then
    chmod u+s "/usr/lib/qemu/qemu-bridge-helper"
  else 
    echo "Error: could not detect os, no qemu-bridge-helper configured"
    return 1
  fi 
}

# Setup the network bridges
function setup_network_bridges {
  echo "Setting up network bridges..."
  for network_bridge in ${NETWORK_BRIDGES}; do
    IFS=':' read -r network bridge <<< "${network_bridge}"
    
    # Check if the bridge is already associated with a different network
    check_bridge_exists ${network} ${bridge}
    if [[ $? -ne 0 ]]; then
      echo "Skipping network ${network} due to bridge conflict."
      continue  # Skip to the next network if there's a bridge conflict
    fi

    if ! virsh net-info ${network} &> /dev/null; then
      define_network ${network} ${bridge}
    else
      echo "Network ${network} with bridge ${bridge} already exists."
    fi
  done
}

# Main function to execute all steps
function main {
  install_packages || exit 1
  manage_libvirtd
  setup_network_bridges
  configure_qemu_bridge_helper
  echo "Setup completed successfully."
  virsh net-list
}

# Execute the main function
main
