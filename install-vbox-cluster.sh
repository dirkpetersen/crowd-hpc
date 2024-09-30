#!/bin/bash

# Constants for Gateway node configuration
GATEWAY_VM="gateway-node"
GATEWAY_RAM=4096          # 4GB RAM
GATEWAY_CPU=2             # 2 CPUs
GATEWAY_DISK_SIZE=20480   # 20GB Disk in MB
# GATEWAY_ISO_URL="https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.4-x86_64-minimal.iso"
GATEWAY_ISO_URL="https://mirror.chpc.utah.edu/pub/rocky/9/isos/x86_64/Rocky-9.4-x86_64-minimal.iso"
LOCAL_ISO_PATH="/tmp/Rocky-9.4-x86_64-minimal.iso"

# Constants for Compute nodes configuration
VM_COUNT=3
VM_PREFIX="compute-node"
COMPUTE_RAM=2048          # 2GB RAM
COMPUTE_CPU=1             # 1 CPU
COMPUTE_DISK_SIZE=10240   # 10GB Disk in MB

# Network configuration
PRIVATE_NET_NAME="private-net"
PUBLIC_NET_NAME="public-net"
VM_OS_TYPE="Linux_64"

# Function to download the ISO only if it's newer on the server
check_and_download_iso() {
  echo "Checking if the remote ISO is newer than the local one..."

  if [[ -f "${LOCAL_ISO_PATH}" ]]; then
    # Get the remote ISO's last modified date
    remote_last_modified=$(curl -sI "${GATEWAY_ISO_URL}" | grep -i "Last-Modified" | awk -F': ' '{print $2}' | tr -d '\r')
    
    if [[ -z "${remote_last_modified}" ]]; then
      echo "Could not retrieve remote ISO last modified date. Proceeding with download."
      download_iso
      return
    fi

    # Convert remote and local file dates to comparable formats
    remote_date=$(date -d "${remote_last_modified}" +%s 2>/dev/null)
    local_date=$(stat -c %Y "${LOCAL_ISO_PATH}")

    # Check if date conversion succeeded
    if [[ -z "${remote_date}" ]]; then
      echo "Could not convert remote date. Proceeding with download."
      download_iso
      return
    fi

    # Compare dates: download if the remote ISO is newer
    if [[ "${remote_date}" -gt "${local_date}" ]]; then
      echo "Remote ISO is newer. Downloading..."
      download_iso
    else
      echo "Local ISO is up-to-date."
    fi
  else
    echo "Local ISO does not exist. Downloading..."
    download_iso
  fi
}

# Function to download the ISO
download_iso() {
  echo "Downloading Rocky Linux ISO from ${GATEWAY_ISO_URL}..."
  curl -L -o "${LOCAL_ISO_PATH}" "${GATEWAY_ISO_URL}"
  if [[ $? -ne 0 ]]; then
    echo "Error downloading the ISO. Exiting."
    exit 1
  fi
  echo "Download completed: ${LOCAL_ISO_PATH}"
}

# Create a private network with 192.168.13.0 subnet
create_private_network() {
  echo "Creating private network: ${PRIVATE_NET_NAME}"
  VBoxManage natnetwork add --netname "${PRIVATE_NET_NAME}" --network "192.168.13.0/24" --enable --dhcp off
}

# Create the gateway node with Rocky Linux ISO and configure serial console
create_gateway_node() {
  echo "Creating gateway node: ${GATEWAY_VM}"
  VBoxManage createvm --name ${GATEWAY_VM} --ostype ${VM_OS_TYPE} --register
  VBoxManage modifyvm ${GATEWAY_VM} --memory ${GATEWAY_RAM} --cpus ${GATEWAY_CPU}
  
  # Create two NICs: one in private, one in public
  VBoxManage modifyvm ${GATEWAY_VM} --nic1 natnetwork --nat-network1 "${PRIVATE_NET_NAME}"
  VBoxManage modifyvm ${GATEWAY_VM} --nic2 nat

  # Create a disk for the gateway node
  VBoxManage createmedium disk --filename "${GATEWAY_VM}.vdi" --size ${GATEWAY_DISK_SIZE}
  VBoxManage storagectl ${GATEWAY_VM} --name "SATA Controller" --add sata --controller IntelAhci
  VBoxManage storageattach ${GATEWAY_VM} --storagectl "SATA Controller" --port 0 --device 0 \
                                     --type hdd --medium "${GATEWAY_VM}.vdi"

  # Attach the Rocky Linux 9.4 Minimal ISO for installation
  VBoxManage storageattach ${GATEWAY_VM} --storagectl "SATA Controller" --port 1 --device 0 \
                                         --type dvddrive --medium "${LOCAL_ISO_PATH}"

  # Configure RDP or serial console 
  # VBoxManage modifyvm ${GATEWAY_VM} --uart1 0x3F8 4 --uartmode1 server /tmp/${GATEWAY_VM}-console
  VBoxManage modifyvm ${GATEWAY_VM} --vrde on
  VBoxManage modifyvm gateway-node --vrdeaddress 192.168.14.1

  echo "Gateway node created, Linux ISO attached, rdesktop activated"
}

# Create compute nodes with their own memory and disk configuration
create_compute_nodes() {
  for ((i=1; i<=${VM_COUNT}; i++)); do
    local vm_name="${VM_PREFIX}-${i}"
    echo "Creating compute node: ${vm_name}"
    
    VBoxManage createvm --name ${vm_name} --ostype ${VM_OS_TYPE} --register
    VBoxManage modifyvm ${vm_name} --memory ${COMPUTE_RAM} --cpus ${COMPUTE_CPU}
    
    # Attach private network to NIC
    VBoxManage modifyvm ${vm_name} --nic1 natnetwork --nat-network1 "${PRIVATE_NET_NAME}"
    
    # Enable PXE boot on the NIC
    VBoxManage modifyvm ${vm_name} --boot1 net

    # Create a disk for the compute node
    VBoxManage createmedium disk --filename "${vm_name}.vdi" --size ${COMPUTE_DISK_SIZE}
    VBoxManage storagectl ${vm_name} --name "SATA Controller" --add sata --controller IntelAhci
    VBoxManage storageattach ${vm_name} --storagectl "SATA Controller" --port 0 --device 0 \
                                       --type hdd --medium "${vm_name}.vdi"
    # Configure RDP or serial console for compute nodes
    #VBoxManage modifyvm ${vm_name} --uart1 0x3F8 4 --uartmode1 server /tmp/${vm_name}-console
    VBoxManage modifyvm ${vm_name} --vrde on    

    echo "Compute node ${vm_name} created, rdesktop activated"
  done
}

# Function to create the entire environment
create_environment() {
  create_private_network
  check_and_download_iso
  create_gateway_node
  create_compute_nodes
}

# Start the environment
start_environment() {
  VBoxManage startvm ${GATEWAY_VM} --type headless
  for ((i=1; i<=${VM_COUNT}; i++)); do
    VBoxManage startvm "${VM_PREFIX}-${i}" --type headless
  done
}

# Main
create_environment
start_environment

