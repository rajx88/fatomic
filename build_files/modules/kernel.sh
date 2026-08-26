#!/bin/bash
set -ouex pipefail

# Only run on the proprietary LTS path
if [ "${NVIDIA_FLAVOR:-lts}" != "lts" ]; then
  echo "NVIDIA_FLAVOR != lts, skipping kernel swap"
  exit 0
fi

# Bypass kernel-install triggering dracut/rpm-ostree during the swap
pushd /usr/lib/kernel/install.d
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

# Remove the stock main kernel shipped by base-main
for pkg in kernel kernel{-core,-modules,-modules-core,-modules-extra,-tools-libs,-tools}; do
  rpm --erase "${pkg}" --nodeps || true
done
rm -rf /usr/lib/modules

# Install the longterm 6.18 kernel from the akmods cache
dnf5 -y install /tmp/kernel-rpms/kernel-longterm*.rpm
dnf5 versionlock add kernel-longterm kernel-longterm-core kernel-longterm-modules

# Install prebuilt proprietary nvidia modules (nvidia-lts) from the akmods cache
AKMODNV_PATH=/tmp/rpms/nvidia /tmp/rpms/nvidia/ublue-os/nvidia-install.sh
systemctl enable nvidia-powerd.service 2>/dev/null || true

# Restore kernel-install shims
pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd

# Rebuild initramfs for the longterm kernel (bazzite's build-initramfs pattern)
QUALIFIED_KERNEL="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel-longterm)"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --zstd -v --add ostree --add fido2 -f "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 /usr/lib/modules/"$QUALIFIED_KERNEL"/initramfs.img
