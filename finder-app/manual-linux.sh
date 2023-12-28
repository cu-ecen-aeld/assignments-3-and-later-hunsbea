#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
TOOLCHAIN_DIR=/home/hunsbea/arm/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
export ARCH=arm64
export CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    echo "Configuring and compiling the kernel, modules, and dtbs"
    make mrproper
    make defconfig
    make -j4 all
    make modules
    make dtbs
fi

echo "Adding the Image in outdir"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}/Image"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

echo "Creating directory structure"
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

if [ ! -e ${OUTDIR}/busybox/busybox ]; then
    echo "Configuring busybox"
    make distclean
    make defconfig
    make
fi
echo "Installing busybox"
make CONFIG_PREFIX="${OUTDIR}/rootfs" install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "program interpreter"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "Shared library"

# Add library dependencies to rootfs
cp "${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib/ld-linux-aarch64.so.1" "${OUTDIR}/rootfs/lib/"
cp "${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libm.so.6" "${OUTDIR}/rootfs/lib64/"
cp "${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libresolv.so.2" "${OUTDIR}/rootfs/lib64/"
cp "${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libc.so.6" "${OUTDIR}/rootfs/lib64/"

# Make device nodes
cd "${OUTDIR}/rootfs"
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/console c 5 1

# Clean and build the writer utility
cd "${FINDER_APP_DIR}"
make clean
make

# Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp -Lr "${FINDER_APP_DIR}/." "${OUTDIR}/rootfs/home/"

# Chown the root directory
sudo chown -R root:root "${OUTDIR}/rootfs"

# Create initramfs.cpio.gz
cd "${OUTDIR}/rootfs"
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"

cd "${OUTDIR}"
gzip -f initramfs.cpio

