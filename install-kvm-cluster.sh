#!/bin/bash

# Define the log directory for console outputs
LOG_DIR="$HOME/kvm-logs"
mkdir -p ${LOG_DIR}

# Constants for Control node configuration
CONTROL_VM="control-node"
CONTROL_RAM=4096          # 4GB RAM
CONTROL_CPU=2             # 2 CPUs
CONTROL_DISK_SIZE=20480   # 20GB Disk in MB (only if it's an ISO and a fresh disk is needed)
CONTROL_IMAGE_URL="https://download.rockylinux.org/pub/rocky/9.4/images/x86_64/Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2"
TMP_IMAGE_PATH="/tmp/$(basename ${CONTROL_IMAGE_URL})"
LOCAL_IMAGE_PATH="$HOME/kvm-images/$(basename ${CONTROL_IMAGE_URL})"

# Constants for Worker nodes configuration
WORKER_COUNT=3
WORKER_PREFIX="worker-node"
WORKER_RAM=2048          # 2GB RAM
WORKER_CPU=1             # 1 CPU
WORKER_DISK_SIZE=10240   # 10GB Disk in MB (empty, boot from PXE)

# Network configuration (no need for private network in user-session mode)
PRIVATE_NET_NAME="default"

# Load support functions from the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/support-functions.sh"

# Function to create Control node using KVM in user-session mode
create_control_node() {
  echo "Creating control node: ${CONTROL_VM}"

  # Check if the file is an ISO or QCOW2
  echo "Image is ${LOCAL_IMAGE_PATH##*.}, ${LOCAL_IMAGE_PATH##*.} == iso ? creating fresh disk : copy qcow2."

  [[ "${LOCAL_IMAGE_PATH}" == *.iso ]] && {
  qemu-img create -f qcow2 "$HOME/kvm-images/${CONTROL_VM}.qcow2" ${CONTROL_DISK_SIZE}M
  DISK_OPTS="path=$HOME/kvm-images/${CONTROL_VM}.qcow2,size=${CONTROL_DISK_SIZE},format=qcow2"
  ISO_OPTS="--cdrom ${LOCAL_IMAGE_PATH}"
  } || {
  DISK_OPTS="path=${LOCAL_IMAGE_PATH},format=qcow2"
  ISO_OPTS="--import"
  }

  virt-install --connect qemu:///session \
              --name ${CONTROL_VM} \
              --memory ${CONTROL_RAM} \
              --vcpus ${CONTROL_CPU} \
              --disk ${DISK_OPTS} \
              --network user \
              --os-variant linux2022 \
              --serial pty \
              --console pty,target_type=serial \
              --cloud-init user-data=cloud-init-user-data \
              --noautoconsole \
              --quiet \
              ${ISO_OPTS}

  echo "Control node created and booting (console output suppressed)."
}

# Function to create worker nodes using KVM in user-session mode
create_worker_nodes() {
  for ((i=1; i<=${WORKER_COUNT}; i++)); do
    local vm_name="${WORKER_PREFIX}-${i}"
    echo "Creating worker node: ${vm_name}"

    # Create a sparse QCOW2 disk image for the worker node
    qemu-img create -f qcow2 -o preallocation=off,cluster_size=16384 "$HOME/kvm-images/${vm_name}.qcow2" ${WORKER_DISK_SIZE}M || { 
      echo "Failed to create disk for ${vm_name}, exiting."; exit 1; 
    }

    # Use virt-install to create the worker node VM in user session mode
    virt-install --connect qemu:///session \
                 --name ${vm_name} \
                 --memory ${WORKER_RAM} \
                 --vcpus ${WORKER_CPU} \
                 --disk path="$HOME/kvm-images/${vm_name}.qcow2",size=${WORKER_DISK_SIZE},format=qcow2 \
                 --network user \
                 --pxe \
                 --os-variant linux2022 \
                 --serial pty \
                 --console pty,target_type=serial \
                 --noautoconsole \
                 --quiet

    echo "Worker node ${vm_name} created and set to boot via PXE (console output suppressed)."

  done
}

# Main function to create environment and start VMs
create_environment() {
  check_kvm_and_nested
  check_and_download_image
  create_control_node
  create_worker_nodes
}

# Execute script
create_environment
