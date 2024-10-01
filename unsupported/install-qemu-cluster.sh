#!/bin/bash

# Define the log directory for console outputs
LOG_DIR="$HOME/kvm-logs"
mkdir -p ${LOG_DIR}

# Constants for Control node configuration
CONTROL_VM="control-node"
CONTROL_RAM=4096          # 4GB RAM
CONTROL_CPU=2             # 2 CPUs
CONTROL_DISK_SIZE=20480   # 20GB Disk in MB (only if it's an ISO and a fresh disk is needed)
#CONTROL_IMAGE_URL="https://download.rockylinux.org/pub/rocky/9.4/images/x86_64/Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2"
CONTROL_IMAGE_URL="https://mirrors.oit.uci.edu/rocky-linux/9/images/x86_64/Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2"

TMP_IMAGE_PATH="/tmp/$(basename ${CONTROL_IMAGE_URL})"
LOCAL_IMAGE_PATH="$HOME/kvm-images/$(basename ${CONTROL_IMAGE_URL})"

# Constants for Worker nodes configuration
WORKER_COUNT=3
WORKER_PREFIX="worker-node"
WORKER_RAM=2048          # 2GB RAM
WORKER_CPU=1             # 1 CPU
WORKER_DISK_SIZE=10240   # 10GB Disk in MB (empty, boot from PXE)

# Network configuration
PRIVATE_NET_NAME="private-net"

# Load support functions from the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/support-functions.sh"

# Create the private network with user-level QEMU (no sudo)
create_private_network() {
  echo "Creating private network: ${PRIVATE_NET_NAME}"
  if ! virsh net-list --all | grep -q "${PRIVATE_NET_NAME}"; then
    virsh net-define <(cat <<EOF
<network>
  <name>${PRIVATE_NET_NAME}</name>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.13.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.13.100' end='192.168.13.200'/>
    </dhcp>
  </ip>
</network>
EOF
)
    virsh net-start ${PRIVATE_NET_NAME}
    virsh net-autostart ${PRIVATE_NET_NAME}
    echo "Private network created and started."
  else
    echo "Private network already exists."
  fi
}

# Function to create Control node with suppressed console output
create_control_node() {
  echo "Creating control node: ${CONTROL_VM}"
  
  # Check if the file is an ISO or QCOW2
  if [[ "${LOCAL_IMAGE_PATH}" == *.iso ]]; then
    echo "Image is an ISO, creating a fresh virtual disk for installation."
    qemu-img create -f qcow2 "$HOME/kvm-images/${CONTROL_VM}.qcow2" ${CONTROL_DISK_SIZE}M

    # Suppress console output and redirect it to a log file
    qemu-system-x86_64 \
      -m ${CONTROL_RAM} \
      -smp ${CONTROL_CPU} \
      -hda "$HOME/kvm-images/${CONTROL_VM}.qcow2" \
      -cdrom "${LOCAL_IMAGE_PATH}" \
      -boot d \
      -net nic -net user \
      -nographic \
      -serial mon:stdio \
      -enable-kvm > "${LOG_DIR}/${CONTROL_VM}.log" 2>&1 &
  else
    echo "Image is a QCOW2 file, using it directly."
    
    # Suppress console output and redirect it to a log file
    qemu-system-x86_64 \
      -m ${CONTROL_RAM} \
      -smp ${CONTROL_CPU} \
      -drive file="${LOCAL_IMAGE_PATH}",format=qcow2 \
      -net nic -net user \
      -nographic \
      -serial mon:stdio \
      -enable-kvm > "${LOG_DIR}/${CONTROL_VM}.log" 2>&1 &
  fi

  echo "Control node created and booting (console output suppressed)."
}

# Function to create worker nodes with suppressed console output
create_worker_nodes() {
  for ((i=1; i<=${WORKER_COUNT}; i++)); do
    local vm_name="${WORKER_PREFIX}-${i}"
    echo "Creating worker node: ${vm_name}"
    
    # Speed up formatting by creating sparse files without compression
    qemu-img create -f qcow2 -o preallocation=off,cluster_size=16384 "$HOME/kvm-images/${vm_name}.qcow2" ${WORKER_DISK_SIZE}M || { 
      echo "Failed to create disk for ${vm_name}, exiting."; exit 1; 
    }

    # Suppress console output and redirect it to a log file
    qemu-system-x86_64 \
      -m ${WORKER_RAM} \
      -smp ${WORKER_CPU} \
      -hda "$HOME/kvm-images/${vm_name}.qcow2" \
      -boot n \
      -net nic -net user \
      -nographic \
      -serial mon:stdio \
      -enable-kvm > "${LOG_DIR}/${vm_name}.log" 2>&1 &

    # Ensure this VM is created before moving on to the next
    wait
      
    echo "Worker node ${vm_name} created and set to boot via PXE (console output suppressed)."
  done
}

# Main function to create environment and start VMs
create_environment() {
  check_kvm_and_nested
  create_private_network
  check_and_download_image
  create_control_node
  create_worker_nodes
}

# Execute script
create_environment
