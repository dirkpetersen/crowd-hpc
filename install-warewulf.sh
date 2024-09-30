#! /bin/bash
#
echo " #########: Installing  Warewulf ! ###############"

# Constants
GITHUB_URL="https://github.com/warewulf/warewulf/releases"
RPM_SUFFIX=".el9.x86_64.rpm"
LATEST_RELEASE_URL="https://api.github.com/repos/warewulf/warewulf/releases/latest"

# Fetch the latest release data
latest_release=$(curl -s ${LATEST_RELEASE_URL})
rpm_url=$(echo ${latest_release} | grep -oP "(?<=browser_download_url\":\")[^\"]+${RPM_SUFFIX}")

# Check if RPM URL was found
if [[ -z "${rpm_url}" ]]; then
  echo "No RPM package with suffix ${RPM_SUFFIX} found in the latest release."
  exit 1
fi

# Install the RPM package
echo "Installing ${rpm_url}..."
dnf install -y "${rpm_url}"
