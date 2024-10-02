#!/bin/bash

# Define the log directory for console outputs
LOG_DIR="$HOME/kvm-logs"
mkdir -p ${LOG_DIR}

# Constants for Control node configuration
CONTROL_VM="control-node"
CONTROL_RAM=4096          # 4GB RAM
CONTROL_CPU=2             # 2 CPUs
CONTROL_DISK_SIZE=20480   # 20GB Disk in MB
CONTROL_IMAGE_URL="https://download.rockylinux.org/pub/rocky/9.4/images/x86_64/Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2"
TMP_IMAGE_PATH="/tmp/$(basename ${CONTROL_IMAGE_URL})"
LOCAL_IMAGE_PATH="$HOME/kvm-images/$(basename ${CONTROL_IMAGE_URL})"

# Constants for Worker nodes configuration
WORKER_COUNT=3
WORKER_PREFIX="worker-node"
WORKER_RAM=2048          # 2GB RAM
WORKER_CPU=1             # 1 CPU
WORKER_DISK_SIZE=10240   # 10GB Disk in MB

# Enable curses mode if true
CURSES_CONSOLE=false

# Load support functions from the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/support-functions.sh"

# Function to create Control node
create_control_node() {
  echo "Creating control node: ${CONTROL_VM}"

  if [[ "${LOCAL_IMAGE_PATH}" == *.iso ]]; then
    qemu-img create -f qcow2 "$HOME/kvm-images/${CONTROL_VM}.qcow2" ${CONTROL_DISK_SIZE}M
    DISK_OPTS="$HOME/kvm-images/${CONTROL_VM}.qcow2"
    BOOT_OPTS="-cdrom ${LOCAL_IMAGE_PATH}"
  else
    DISK_OPTS="${LOCAL_IMAGE_PATH}"
    BOOT_OPTS="-drive file=${DISK_OPTS},format=qcow2"
  fi

  if [[ "${CURSES_CONSOLE}" == true ]]; then
    echo "Starting control node with qemu-system-x86_64 in curses mode..."
    qemu-system-x86_64 \
      -enable-kvm \
      -name ${CONTROL_VM} \
      -m ${CONTROL_RAM} \
      -smp ${CONTROL_CPU} \
      ${BOOT_OPTS} \
      -drive file="${DISK_OPTS}",format=qcow2 \
      -display curses \
      -serial mon:stdio \
      -netdev user,id=net0 -device virtio-net,netdev=net0 \
      -netdev user,id=net1 -device virtio-net,netdev=net1 &
  else
    echo "Starting control node with virt-install..."
    virt-install --connect qemu:///session \
                --name ${CONTROL_VM} \
                --memory ${CONTROL_RAM} \
                --vcpus ${CONTROL_CPU} \
                --disk path="${DISK_OPTS}",size=${CONTROL_DISK_SIZE},format=qcow2 \
                --network bridge=virbr0,model=virtio \
                --network bridge=virbr1,model=virtio \
                --network bridge=virbr2,model=virtio \
                --network bridge=virbr3,model=virtio \
                --os-variant linux2022 \
                --cloud-init user-data=cloud-init-user-data \
                --serial pty \
                --console pty,target_type=serial \
                --noautoconsole \
                --import \
                --quiet
  fi
}

# Function to create worker nodes
create_worker_nodes() {
  for ((i=1; i<=${WORKER_COUNT}; i++)); do
    local vm_name="${WORKER_PREFIX}-${i}"
    echo "Creating worker node: ${vm_name}"

    qemu-img create -f qcow2 -o preallocation=off,cluster_size=16384 "$HOME/kvm-images/${vm_name}.qcow2" ${WORKER_DISK_SIZE}M || { 
      echo "Failed to create disk for ${vm_name}, exiting."; exit 1; 
    }

    if [[ "${CURSES_CONSOLE}" == true ]]; then
      echo "Starting worker node ${vm_name} with qemu-system-x86_64 in curses mode..."
      qemu-system-x86_64 \
        -enable-kvm \
        -name ${vm_name} \
        -m ${WORKER_RAM} \
        -smp ${WORKER_CPU} \
        -boot menu=on \
        -drive file="$HOME/kvm-images/${vm_name}.qcow2",format=qcow2 \
        -display curses \
        -serial mon:stdio \
        -netdev user,id=net0 -device virtio-net,netdev=net0 &
    else
      echo "Starting worker node ${vm_name} with virt-install (no curses)..."
      virt-install --connect qemu:///session \
                   --name ${vm_name} \
                   --memory ${WORKER_RAM} \
                   --vcpus ${WORKER_CPU} \
                   --disk path="$HOME/kvm-images/${vm_name}.qcow2",size=${WORKER_DISK_SIZE},format=qcow2 \
                   --network bridge=virbr1,model=virtio \
                   --network bridge=virbr2,model=virtio \
                   --network bridge=virbr3,model=virtio \
                   --pxe \
                   --os-variant linux2022 \
                   --serial pty \
                   --console pty,target_type=serial \
                   --noautoconsole \
                   --quiet
    fi
  done
}


# Main function to create environment and start VMs
create_environment() {
  check_kvm_and_nested
  check_and_download_image
  create_control_node
  create_worker_nodes
  #cnip=$(jq -r '.[] | select(.hostname=="control-node") | .["ip-address"]' /var/lib/libvirt/dnsmasq/virbr0.status)
  #OR ssh rocky@${cnip}
  echo "Run: virsh console control-node"
}

# Execute script
create_environment