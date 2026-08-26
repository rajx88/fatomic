#!/bin/bash
set -ouex pipefail

# Copy any common config shipped in system_files/common/
cp -avf /ctx/system_files/common/. / 2>/dev/null || true

# Base utilities (what the template originally shipped)
dnf5 install -y tmux

# Services
systemctl enable podman.socket
systemctl enable greenboot-healthcheck.service 2>/dev/null || true

# ujust is already present on base-main. For secure boot, enroll ublue's
# akmods signing key once on the running machine:
#   sudo ujust enroll-secure-boot-key
