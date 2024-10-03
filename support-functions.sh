## support-functions.sh

# functions that are sourced by other scripts. 

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

# Function to detect if running on KVM and check for nested virtualization support
check_kvm_and_nested() {
  if [[ ! -d /sys/module/kvm ]]; then
    echo "This system is not a KVM guest. Skipping"
    return 0
  fi

  # Check for nested virtualization support
  if [[ -f /sys/module/kvm_intel/parameters/nested ]]; then
    nested=$(cat /sys/module/kvm_intel/parameters/nested)
    if [[ "${nested}" != "Y" ]]; then
      echo "KVM detected but nested virtualization is not enabled (Intel). Exiting."
      exit 1
    fi
  elif [[ -f /sys/module/kvm_amd/parameters/nested ]]; then
    nested=$(cat /sys/module/kvm_amd/parameters/nested)
    if [[ "${nested}" != "Y" ]]; then
      echo "KVM detected but nested virtualization is not enabled (AMD). Exiting."
      exit 1
    fi
  else
    echo "KVM detected, but unable to verify nested virtualization. Exiting."
    exit 1
  fi

  echo "KVM detected with nested virtualization enabled."
}

# Function to download the image only if it's newer on the server, and copy it to the final location
check_and_download_image() {
  echo "Checking if the remote image is newer than the local one..."
  mkdir -p "$HOME/kvm-images"

  # Fetch the Last-Modified date from the server
  remote_last_modified=$(curl -sI "${CONTROL_IMAGE_URL}" | grep -i "Last-Modified" | awk -F': ' '{print $2}' | tr -d '\r')
  
  if [[ -z "${remote_last_modified}" ]]; then
    echo "Could not retrieve remote image's Last-Modified date. Proceeding with download."
    download_image
    return
  fi

  # Convert the remote Last-Modified date to Unix timestamp
  remote_date=$(date -d "${remote_last_modified}" +%s 2>/dev/null)

  if [[ -f "${TMP_IMAGE_PATH}" ]]; then
    # Get the modification date of the local file and convert it to Unix timestamp
    local_date=$(stat -c %Y "${TMP_IMAGE_PATH}")
    
    # Compare dates: download if the remote image is newer
    if [[ "${remote_date}" -gt "${local_date}" ]]; then
      echo "Remote image is newer. Downloading..."
      download_image
    else
      echo "Local image in /tmp is up-to-date."
    fi
  else
    echo "Local image in /tmp does not exist. Downloading..."
    download_image
  fi

  # Copy the image to the final destination
  echo "Copying QCOW2 image from /tmp to ${LOCAL_IMAGE_PATH}..."
  cp --preserve=timestamps "${TMP_IMAGE_PATH}" "${LOCAL_IMAGE_PATH}"
}

# Function to download the image from the server and set the correct modification date
download_image() {
  echo "Downloading image from ${CONTROL_IMAGE_URL} to /tmp..."
  
  # Download the file
  curl -L -o "${TMP_IMAGE_PATH}" "${CONTROL_IMAGE_URL}"
  if [[ $? -ne 0 ]]; then
    echo "Error downloading the image. Exiting."
    exit 1
  fi

  echo "Download completed: ${TMP_IMAGE_PATH}"

  # Set the modification time of the file to match the remote Last-Modified date
  echo "Setting modification time of the file to: ${remote_last_modified}"
  touch -d "${remote_last_modified}" "${TMP_IMAGE_PATH}"
}

# Function to edit the VM XML for curses graphics
edit_vm_graphics_to_curses() {
  local vm_name="$1"

  echo "Editing the graphics section for VM: ${vm_name} to use curses..."

  # Backup the current XML
  virsh --connect qemu:///session dumpxml "${vm_name}" > /tmp/${vm_name}_backup.xml

  # Modify the XML to use curses graphics
  virsh --connect qemu:///session dumpxml "${vm_name}" | \
    sed 's/<graphics .*\/>/<graphics type="curses"\/>/' > /tmp/${vm_name}_modified.xml

  # Apply the modified XML
  virsh --connect qemu:///session define /tmp/${vm_name}_modified.xml

  # Cleanup the temporary XML file
  rm /tmp/${vm_name}_modified.xml
}