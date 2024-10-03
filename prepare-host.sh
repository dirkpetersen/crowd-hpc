#!/bin/bash

# Run this to prepare the host/hypervisor that will run all cluster VMs 

# Ensure the script is run as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

# Constants which can be overwritten by environment vars
DEBIAN_PKG="${DEBIAN_PKG:-qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virtinst virtualbmc}"
REDHAT_PKG="${REDHAT_PKG:-qemu-kvm libvirt virt-install bridge-utils python3-pip}"
NETWORK_BRIDGES="${NETWORK_BRIDGES:-default:virbr0 pxe:virbr1 ipmi:virbr2 storage:virbr3}"
QEMU_HELPER="qemu-bridge-helper"

# Load support functions from the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/support-functions.sh"

OS_FAMILY=$(check_os_family)


# Install packages based on OS type
function install_packages {
  if [[ "${OS_FAMILY}" == "debian" ]]; then
    apt update && DEBIAN_FRONTEND=noninteractive apt install -y ${DEBIAN_PKG}
    QEMU_HELPER="/usr/lib/qemu/qemu-bridge-helper"

  elif [[ "${OS_FAMILY}" == "redhat" ]]; then 
    dnf install -y ${REDHAT_PKG}
    QEMU_HELPER="/usr/libexec/qemu-bridge-helper"
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
      echo -e "${YELLOW}  virsh net-destroy ${existing_network} && virsh net-undefine ${existing_network}${NC}"
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

  # Set setuid on qemu-bridge-helper
  echo "Setting setuid on ${QEMU_HELPER} ..."  
  chmod u+s ${QEMU_HELPER}

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
  detect_os
  install_packages
  manage_libvirtd
  setup_network_bridges
  configure_qemu_bridge_helper
  manage_libvirtd
  echo "Setup completed successfully."
  virsh net-list
}

# Execute the main function
main
