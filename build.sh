#!/bin/bash
#
# Created by Igor Pecovnik, www.igorpecovnik.com
#
# --- Configuration -------------------------------------------------------------
#
#

RELEASE="wheezy"                                   # jessie(currently broken) or wheezy
VERSION="Cubox Debian 1.3 $RELEASE"                # just name
SOURCE_COMPILE="yes"                               # yes / no
DEST_LANG="en_US.UTF-8"                            # sl_SI.UTF-8, en_US.UTF-8
TZDATA="Europe/Ljubljana"                          # Timezone
DEST=$(pwd)/output                                 # Destination
ROOTPWD="1234"                                     # Must be changed @first login
HOST="cubox"									   # Hostname

#
#
# --- End -----------------------------------------------------------------------

# source is where we start the script
SRC=$(pwd)
set -e

# optimize build time with 100% CPU usage
CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS="-j$(($CPUS + $CPUS/2))"
#CTHREADS="-j${CPUS}" # or not

# to display build time at the end
start=`date +%s`

# root is required ...
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

clear
echo "Building $VERSION."

#--------------------------------------------------------------------------------
# Downloading necessary files
#--------------------------------------------------------------------------------
echo "Downloading necessary files."
apt-get -qq -y install lzop zip binfmt-support bison build-essential ccache debootstrap flex gawk gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf lvm2 qemu-user-static u-boot-tools uuid-dev zlib1g-dev unzip libncurses5-dev pkg-config libusb-1.0-0-dev parted

#--------------------------------------------------------------------------------
# Preparing output / destination files
#--------------------------------------------------------------------------------

echo "Fetching files from Github."
mkdir -p $DEST/output

if [ -d "$DEST/u-boot-cubox" ]
then
	cd $DEST/u-boot-cubox ; git pull; cd $SRC
else
   git clone https://github.com/SolidRun/u-boot-imx6 $DEST/u-boot-cubox 
fi

#if [ -d "$DEST/linux-cubox" ]
#then
#	cd $DEST/linux-cubox; git pull -f; cd $SRC
#else
#	git clone https://github.com/SolidRun/linux-imx6 $DEST/linux-cubox              # Stable kernel source
#fi

if [ -d "$DEST/linux-cubox-next" ]
then
	cd $DEST/linux-cubox-next; git pull -f; cd $SRC
else
	git clone https://github.com/linux4kix/linux-linaro-stable-mx6 -b linux-linaro-lsk-v3.14-mx6 $DEST/linux-cubox-next              # Dev kernel source
fi

if [ "$SOURCE_COMPILE" = "yes" ]; then

#--------------------------------------------------------------------------------
# Patching
#--------------------------------------------------------------------------------

# Applying patch for crypt and some performance tweaks
# cd $DEST/linux-cubox-next 
# patch -p1 < $SRC/patch/patch-3.16.1

#--------------------------------------------------------------------------------
# Compiling everything
#--------------------------------------------------------------------------------

# clean output
rm -rf $DEST/linux-cubox/output

# boot loader
echo "------ Compiling universal boot loader"
cd $DEST/u-boot-cubox
make CROSS_COMPILE=arm-linux-gnueabihf- clean
make $CTHREADS mx6_cubox-i_config CROSS_COMPILE=arm-linux-gnueabihf- 
make $CTHREADS CROSS_COMPILE=arm-linux-gnueabihf-

# kernel image
#cd $DEST/linux-cubox
#make CROSS_COMPILE=arm-linux-gnueabihf- clean
#cp $SRC/config/kernel.config $DEST/linux-cubox/.config
#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx6_cubox-i_hummingboard_defconfig
#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage modules LOCALVERSION="-cubox" 
#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output/usr headers_install
#cp $DEST/linux-cubox-next/Module.symvers $DEST/linux-cubox-next/output/usr/include

# kernel image next
rm -rf $DEST/linux-cubox-next/output
cd $DEST/linux-cubox-next
tar xvfz $SRC/bin/wifi-firmware.tgz
make CROSS_COMPILE=arm-linux-gnueabihf- clean
cp $SRC/config/kernel.config.next $DEST/linux-cubox-next/.config
#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx_v7_cbi_hb_base_defconfig # default config
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage modules imx6q-cubox-i.dtb imx6dl-cubox-i.dtb imx6dl-hummingboard.dtb imx6q-hummingboard.dtb LOCALVERSION="-cubox"
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output/usr headers_install
cp $DEST/linux-cubox-next/Module.symvers $DEST/linux-cubox-next/output/usr/include
fi



#--------------------------------------------------------------------------------
# Creating boot directory for current and next kernel
#--------------------------------------------------------------------------------
# 
rm -r $DEST/output/boot/
mkdir -p $DEST/output/boot/
# Current 
#cp $SRC/config/kernel-switching.txt $DEST/output/boot/
cp $SRC/config/uEnv.* $DEST/output/boot/
cp $DEST/u-boot-cubox/u-boot.img $DEST/output/u-boot.img
cp $DEST/u-boot-cubox/SPL $DEST/output/SPL
#cp $SRC/output/linux-cubox/arch/arm/boot/uImage $DEST/output/boot/uImage
cp $SRC/output/linux-cubox-next/arch/arm/boot/zImage $DEST/output/boot/zImage
cp $DEST/linux-cubox-next/arch/arm/boot/dts/imx6*.dtb $DEST/output/boot/

#--------------------------------------------------------------------------------
# Creating kernel packages: modules + headers + firmware
#--------------------------------------------------------------------------------
#
# Current
#VER=$(cat $DEST/linux-cubox/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
#VER=$VER.$(cat $DEST/linux-cubox/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
#VER=$VER.$(cat $DEST/linux-cubox/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
#cd $SRC/output/linux-cubox/output
#rm -f $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar"
#tar cPf $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar" *
#cd $DEST/output/
#tar rPf $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar" boot/*
# creating MD5 sum
#md5sum cubox_kernel_"$VER"_mod_head_fw.tar > cubox_kernel_"$VER"_mod_head_fw.md5
#zip cubox_kernel_"$VER"_mod_head_fw.zip cubox_kernel_"$VER"_mod_head_fw.*



# Next
VER=$(cat $DEST/linux-cubox-next/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-cubox-next/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-cubox-next/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
cd $SRC/output/linux-cubox-next/output
rm -f $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar"
tar cPf $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar" *
cd $DEST/output/
tar rPf $DEST"/output/cubox_kernel_"$VER"_mod_head_fw.tar" boot/*
# creating MD5 sum
md5sum cubox_kernel_"$VER"_mod_head_fw.tar > cubox_kernel_"$VER"_mod_head_fw.md5
zip cubox_kernel_"$VER"_mod_head_fw.zip cubox_kernel_"$VER"_mod_head_fw.*

#--------------------------------------------------------------------------------
# Creating SD Images
#--------------------------------------------------------------------------------
echo "------ Creating SD Images"
cd $DEST/output
# create 1G image and mount image to next free loop device
dd if=/dev/zero of=debian_rootfs.raw bs=1M count=1000 status=noxfer
sleep 3
LOOP=$(losetup -f)
losetup $LOOP debian_rootfs.raw
sync

echo "Partitioning, writing boot loader and mounting file-system."
# create one partition starting at 2048 which is default
parted -s $LOOP -- mklabel msdos
sleep 1
parted -s $LOOP -- mkpart primary ext4  2048s -1s
sleep 1
partprobe $LOOP
sleep 1

echo "Writing boot loader."
dd if=$DEST/output/SPL of=$LOOP bs=512 seek=2 status=noxfer
dd if=$DEST/output/u-boot.img of=$LOOP bs=1K seek=42 status=noxfer
rm $DEST/output/SPL
rm $DEST/output/u-boot.img
sync
sleep 5
losetup -d $LOOP
sleep 4

# 2048 (start) x 512 (block size) = where to mount partition
losetup -o 1048576 $LOOP debian_rootfs.raw
sleep 4

# create filesystem
mkfs.ext4 $LOOP

# tune filesystem
tune2fs -o journal_data_writeback $LOOP

# label it
e2label $LOOP "Root"

# create mount point and mount image 
mkdir -p $DEST/output/sdcard/

mount -t ext4 $LOOP $DEST/output/sdcard/

echo "------ Install basic filesystem"
# install base system
debootstrap --no-check-gpg --arch=armhf --foreign $RELEASE $DEST/output/sdcard/
# we need this
cp /usr/bin/qemu-arm-static $DEST/output/sdcard/usr/bin/
# enable arm binary format so that the cross-architecture chroot environment will work
test -e /proc/sys/fs/binfmt_misc/qemu-arm || update-binfmts --enable qemu-arm
# mount proc inside chroot
mount -t proc chproc $DEST/output/sdcard/proc
# second stage unmounts proc 
chroot $DEST/output/sdcard /bin/bash -c "/debootstrap/debootstrap --second-stage"
# mount proc, sys and dev
mount -t proc chproc $DEST/output/sdcard/proc
mount -t sysfs chsys $DEST/output/sdcard/sys
# This works on half the systems I tried.  Else use bind option
mount -t devtmpfs chdev $DEST/output/sdcard/dev || mount --bind /dev $DEST/output/sdcard/dev
mount -t devpts chpts $DEST/output/sdcard/dev/pts

# update /etc/issue
cat <<EOT > $DEST/output/sdcard/etc/issue
Debian GNU/Linux $VERSION

EOT

# update /etc/motd
rm $DEST/output/sdcard/etc/motd
touch $DEST/output/sdcard/etc/motd

# choose proper apt list
cp $SRC/config/sources.list.$RELEASE $DEST/output/sdcard/etc/apt/sources.list

#cat <<EOT > $DEST/output/sdcard/etc/apt/sources.list
# your custom repo
#EOT

# update, fix locales
chroot $DEST/output/sdcard /bin/bash -c "apt-get update"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install locales makedev"
sed -i "s/^# $DEST_LANG/$DEST_LANG/" $DEST/output/sdcard/etc/locale.gen
chroot $DEST/output/sdcard /bin/bash -c "locale-gen $DEST_LANG"
chroot $DEST/output/sdcard /bin/bash -c "export LANG=$DEST_LANG LANGUAGE=$DEST_LANG DEBIAN_FRONTEND=noninteractive"
chroot $DEST/output/sdcard /bin/bash -c "update-locale LANG=$DEST_LANG LANGUAGE=$DEST_LANG LC_MESSAGES=POSIX"

# set up 'apt
cat <<END > $DEST/output/sdcard/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END

# script to show boot splash
cp $SRC/scripts/bootsplash $DEST/output/sdcard/etc/init.d/bootsplash
# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/bootsplash"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d bootsplash defaults" 

# scripts for autoresize at first boot from cubian
cd $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-resize2fs $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-firstrun $DEST/output/sdcard/etc/init.d

# script to install to NAND & SATA and kernel switchers
cp $SRC/bin/ramlog_2.0.0_all.deb $DEST/output/sdcard/tmp

# bluetooth device enabler
cd $DEST/output/sdcard/
tar xvfz $SRC/bin/bt-firmware.tgz 
cp $SRC/bin/brcm_patchram_plus $DEST/output/sdcard/usr/local/bin
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /usr/local/bin/brcm_patchram_plus"
cp $SRC/scripts/brcm4330 $DEST/output/sdcard/etc/default
cp $SRC/scripts/brcm4330-patch $DEST/output/sdcard/etc/init.d
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/brcm4330-patch"
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d brcm4330-patch defaults" 

# install custom bashrc
cat $SRC/scripts/bashrc >> $DEST/output/sdcard/etc/bash.bashrc 

# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/cubian-*"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d cubian-firstrun defaults" 
echo "Installing aditional applications"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install i2c-tools bluetooth libbluetooth3 libbluetooth-dev stress u-boot-tools makedev libfuse2 libc6 libnl-3-dev sysfsutils hddtemp bc figlet toilet screen hdparm libfuse2 ntfs-3g bash-completion lsof sudo git hostapd dosfstools htop openssh-server ca-certificates module-init-tools dhcp3-client udev ifupdown iproute iputils-ping ntp rsync usbutils pciutils wireless-tools wpasupplicant procps parted cpufrequtils unzip bridge-utils"
# removed in 2.4 #chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install lirc alsa-utils console-setup console-data"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -y clean"

# change dynamic motd
ZAMENJAJ='echo "" > /var/run/motd.dynamic'
ZAMENJAJ=$ZAMENJAJ"\n   if [ \$(cat /proc/meminfo | grep MemTotal | grep -o '[0-9]\\\+') -ge 1531749 ]; then"
ZAMENJAJ=$ZAMENJAJ"\n           toilet -f standard -F metal  \"Cubox-i PRO\" >> /var/run/motd.dynamic"
ZAMENJAJ=$ZAMENJAJ"\n   else"
ZAMENJAJ=$ZAMENJAJ"\n           toilet -f standard -F metal  \"Cubox-i\" >> /var/run/motd.dynamic"
ZAMENJAJ=$ZAMENJAJ"\n   fi"
ZAMENJAJ=$ZAMENJAJ"\n   echo \"\" >> /var/run/motd.dynamic"
sed -e s,"# Update motd","$ZAMENJAJ",g 	-i $DEST/output/sdcard/etc/init.d/motd
sed -e s,"uname -snrvm > /var/run/motd.dynamic","",g  -i $DEST/output/sdcard/etc/init.d/motd

# copy lirc configuration
#cp $DEST/sunxi-lirc/lirc_init_files/hardware.conf $DEST/output/sdcard/etc/lirc
#cp $DEST/sunxi-lirc/lirc_init_files/init.d_lirc $DEST/output/sdcard/etc/init.d/lirc

# ramlog
chroot $DEST/output/sdcard /bin/bash -c "dpkg -i /tmp/ramlog_2.0.0_all.deb"
sed -e 's/TMPFS_RAMFS_SIZE=/TMPFS_RAMFS_SIZE=256m/g' -i $DEST/output/sdcard/etc/default/ramlog
sed -e 's/# Required-Start:    $remote_fs $time/# Required-Start:    $remote_fs $time ramlog/g' -i $DEST/output/sdcard/etc/init.d/rsyslog 
sed -e 's/# Required-Stop:     umountnfs $time/# Required-Stop:     umountnfs $time ramlog/g' -i $DEST/output/sdcard/etc/init.d/rsyslog   

# console
chroot $DEST/output/sdcard /bin/bash -c "export TERM=linux" 

# Change Time zone data
echo $TZDATA > $DEST/output/sdcard/etc/timezone
chroot $DEST/output/sdcard /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata"

# configure MIN / MAX Speed for cpufrequtils
sed -e 's/MIN_SPEED="0"/MIN_SPEED="792000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/MAX_SPEED="0"/MAX_SPEED="996000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/ondemand/interactive/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils

# set root password
chroot $DEST/output/sdcard /bin/bash -c "(echo $ROOTPWD;echo $ROOTPWD;) | passwd root" 
# force password change upon first login 
chroot $DEST/output/sdcard /bin/bash -c "chage -d 0 root" 

if [ "$RELEASE" = "jessie" ]; then
# enable root login for latest ssh on jessie
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' $DEST/output/sdcard/etc/ssh/sshd_config || fail
fi

# set hostname 
echo $HOST > $DEST/output/sdcard/etc/hostname

# set hostname in hosts file
cat > $DEST/output/sdcard/etc/hosts <<EOT
127.0.0.1   localhost cubie
::1         localhost cubie ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOT

# change default I/O scheduler, noop for flash media and SSD, cfq for mechanical drive
cat <<EOT >> $DEST/output/sdcard/etc/sysfs.conf
block/mmcblk0/queue/scheduler = noop
EOT

# load modules
cat <<EOT >> $DEST/output/sdcard/etc/modules
EOT
# create copy
cp $DEST/output/sdcard/etc/modules $DEST/output/sdcard/etc/modules.current
# create for next
touch $DEST/output/sdcard/etc/modules.next


# create interfaces configuration
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
hwaddress ether # comment this if you want to have MAC from chip
#auto wlan0
#allow-hotplug wlan0
#iface wlan0 inet dhcp
#    wpa-ssid SSID 
#    wpa-psk xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# to generate proper encrypted key: wpa_passphrase yourSSID yourpassword
EOT


# create interfaces if you want to have AP. /etc/modules must be: bcmdhd op_mode=2
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces.hostapd
auto lo br0
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual

iface br0 inet dhcp
bridge_ports eth0 wlan0
hwaddress ether # comment this if you want to have MAC from chip
EOT

# add noatime to root FS
cat <<EOT >> $DEST/output/sdcard/etc/fstab
/dev/mmcblk0p1  /           ext4    defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro        0       0

EOT
# flash media tunning
sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i $DEST/output/sdcard/etc/default/tmpfs
sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#TMP_SIZE=/TMP_SIZE=1G/g' -i $DEST/output/sdcard/etc/default/tmpfs 

# enable serial console (Debian/sysvinit way)
echo T0:2345:respawn:/sbin/getty -L ttymxc0 115200 vt100 >> $DEST/output/sdcard/etc/inittab

# uncompress kernel
cd $DEST/output/sdcard/
ls ../*.tar | xargs -i tar xf {}

sleep 5
rm $DEST/output/*.md5
rm $DEST/output/*.tar
# remove false links to the kernel source
find $DEST/output/sdcard/lib/modules -type l -exec rm -f {} \;

# USB redirector tools http://www.incentivespro.com
cd $DEST
wget http://www.incentivespro.com/usb-redirector-linux-arm-eabi.tar.gz
tar xvfz usb-redirector-linux-arm-eabi.tar.gz
rm usb-redirector-linux-arm-eabi.tar.gz
cd $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNELDIR=$DEST/linux-cubox-next/
# configure USB redirector
sed -e 's/%INSTALLDIR_TAG%/\/usr\/local/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%PIDFILE_TAG%/\/var\/run\/usbsrvd.pid/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
sed -e 's/%STUBNAME_TAG%/tusbd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%DAEMONNAME_TAG%/usbsrvd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
chmod +x $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
# copy to root
cp $DEST/usb-redirector-linux-arm-eabi/files/usb* $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd/tusbd.ko $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd $DEST/output/sdcard/etc/init.d/
# not started by default ----- update.rc rc.usbsrvd defaults
# chroot $DEST/output/sdcard /bin/bash -c "update-rc.d rc.usbsrvd defaults"

# hostapd from testing binary replace.
cd $DEST/output/sdcard/usr/sbin/
tar xvfz $SRC/bin/hostapd23.tgz
cp $SRC/config/hostapd.conf $DEST/output/sdcard/etc/

# temper binary for USB temp meter
cd $DEST/output/sdcard/usr/local/bin
tar xvfz $SRC/bin/temper.tgz
sync
sleep 3

# cleanup 
# unmount proc, sys and dev from chroot
umount -l $DEST/output/sdcard/dev/pts
umount -l $DEST/output/sdcard/dev
umount -l $DEST/output/sdcard/proc
umount -l $DEST/output/sdcard/sys

# let's create nice file name
VERSION="${VERSION// /_}"
#####

sleep 4
killall ntpd
rm $DEST/output/sdcard/usr/bin/qemu-arm-static 
# umount images 
umount -l $DEST/output/sdcard/ 
sleep 4
losetup -d $LOOP



mv $DEST/output/debian_rootfs.raw $DEST/output/$VERSION.raw
cd $DEST/output/
# creating MD5 sum
md5sum $VERSION.raw > $VERSION.md5
zip $VERSION.zip $VERSION.*
rm $VERSION.raw $VERSION.md5

end=`date +%s`
runtime=$((end-start))
echo "Runtime $runtime sec."
