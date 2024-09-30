#!/bin/bash
#
echo " #########: Installing  Warewulf ! ###############"

# Constants
GITHUB_API_URL="https://api.github.com/repos/warewulf/warewulf/releases/latest"
RPM_SUFFIX=".el9.x86_64.rpm"

# Fetch the latest release data from the GitHub API
latest_release=$(curl -s ${GITHUB_API_URL})

# Extract the download URL for the .el9.x86_64.rpm file
rpm_url=$(echo "${latest_release}" | grep -oP '(?<="browser_download_url": ")[^""]*' | grep "${RPM_SUFFIX}")

# Check if an RPM URL was found
if [[ -z "${rpm_url}" ]]; then
  echo "No .el9.x86_64.rpm file found in the latest release."
  exit 1
fi

# Install the RPM using sudo dnf
echo "Installing ${rpm_url}..."
sudo dnf install -y "${rpm_url}"