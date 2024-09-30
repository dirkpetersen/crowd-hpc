#!/bin/bash

# Base directory where resources are stored
BASE_DIR="$HOME"

# Function to delete all KVM virtual machines in user-session mode
delete_kvm_vms() {
  echo "Deleting all KVM instances in user session..."

  # Get the list of all VMs in user-session mode
  vm_list=$(virsh --connect qemu:///session list --all --name)

  if [[ -z "${vm_list}" ]]; then
    echo "No KVM instances found."
  else
    for vm in ${vm_list}; do
      if [[ -n "${vm}" ]]; then
        echo "Shutting down and deleting VM: ${vm}"
        
        # Attempt to shutdown the VM gracefully, ignore errors if already shut down
        virsh --connect qemu:///session destroy "${vm}" 2>/dev/null || echo "VM ${vm} is already stopped or failed to stop."

        # Undefine the VM, suppress unnecessary "already undefined" message
        virsh --connect qemu:///session undefine "${vm}" --remove-all-storage 2>/dev/null || echo "Failed to undefine VM ${vm}."
      fi
    done
  fi
}

# Function to delete all disk images, logs, etc., from $HOME/kvm-images and $HOME/kvm-logs
delete_kvm_files() {
  echo "Deleting KVM-related files in user session..."

  qemu_image_dir="$BASE_DIR/kvm-images"
  qemu_log_dir="$BASE_DIR/kvm-logs"

  # Remove disk images
  if [[ -d "${qemu_image_dir}" ]]; then
    echo "Deleting all QCOW2 disk images from ${qemu_image_dir}..."
    find "${qemu_image_dir}" -type f -name "*.qcow2" -exec rm -f {} \;
    echo "Disk images deleted."
  else
    echo "No QCOW2 disk images directory found."
  fi

  # Remove log files
  if [[ -d "${qemu_log_dir}" ]]; then
    echo "Deleting all log files from ${qemu_log_dir}..."
    find "${qemu_log_dir}" -type f -name "*.log" -exec rm -f {} \;
    echo "Log files deleted."
  else
    echo "No log files directory found."
  fi
}

# Main cleanup function
delete_all_resources() {
  delete_kvm_vms
  delete_kvm_files
  echo "All KVM resources in user session cleaned up."
}

# Execute the cleanup
delete_all_resources
