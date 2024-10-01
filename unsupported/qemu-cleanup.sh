#!/bin/bash

# Base directory where resources are stored
BASE_DIR="$HOME"

# Function to delete all QEMU virtual machines started with qemu-system-x86_64
delete_qemu_vms() {
  echo "Deleting all QEMU instances..."

  # List all running QEMU processes with 'qemu-system-x86_64' and extract PIDs
  qemu_pids=$(pgrep -f "qemu-system-x86_64")

  if [[ -z "${qemu_pids}" ]]; then
    echo "No QEMU instances found."
  else
    for pid in ${qemu_pids}; do
      if [[ -n "${pid}" ]]; then
        echo "Killing QEMU instance with PID: ${pid}"
        kill -9 "${pid}" 2>/dev/null || echo "Failed to kill QEMU process with PID ${pid}."
      fi
    done
  fi
}

# Function to delete all disk images, logs, etc., from $HOME/qemu-images and $HOME/qemu-logs
delete_qemu_files() {
  echo "Deleting QEMU-related files..."

  qemu_image_dir="$BASE_DIR/qemu-images"
  qemu_log_dir="$BASE_DIR/qemu-logs"

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
  delete_qemu_vms
  delete_qemu_files
  echo "All QEMU resources cleaned up."
}

# Execute the cleanup
delete_all_resources

