#!/bin/bash
# Copyright (c) 2024 Hewlett-Packard Development Company, L.P.
# Copyright (c) 2024 Open Compute Project
# MIT based license

echo "starting image build ...."
echo "CPU target currently set to $arch"
sleep 5

arch="amd64"

rm linux_$arch.img linux_$arch.img.gz
dd if=/dev/zero of=linux_$arch.img bs=1024 count=1 seek=4096k
parted -s ./linux_$arch.img mklabel gpt
parted -s --align=optimal ./linux_$arch.img mkpart ESP fat32 1MiB 512MiB
parted -s --align=optimal ./linux_$arch.img mkpart ext4 512MiB 100%
# parted -s ./linux.img set 1 bios_grub on
fdisk ./linux_$arch.img <<EOF
t
1
1
w
EOF
# parted -s linux.img -- mklabel gpt mkpart primary 1m 4g toggle 1 boot
mydev=`sudo losetup --show -f linux_$arch.img`
echo $mydev
sudo partprobe $mydev
sudo mkfs -t fat ${mydev}p1
sudo mkfs -t ext4 ${mydev}p2
sudo mkdir ./mnt
sudo mount -o loop ${mydev}p2 ./mnt
sudo add-apt-repository universe
sudo apt update
sudo apt install debootstrap arch-install-scripts
if [ "$arch" == "amd64" ]
then
        sudo debootstrap --arch=amd64 --components=main,contrib --include=linux-image-generic,apt jammy ./mnt http://ftp.ubuntu.com/ubuntu/
else
        sudo mkdir ./mnt/usr
        sudo mkdir ./mnt/usr/bin
        sudo cp $qemu ./mnt/usr/bin/qemu-aarch64-static
        sudo debootstrap --arch=arm64 --components=main,contrib --include=linux-image-generic,apt jammy ./mnt http://ports.ubuntu.com/ubuntu-ports/
fi
sudo chroot ./mnt rm etc/resolv.conf
sudo chroot ./mnt bash -c 'echo "nameserver 8.8.8.8" > etc/resolv.conf'
sudo chroot ./mnt bash -c 'echo "nameserver 8.8.4.4" >> etc/resolv.conf'
if [ "$arch" == "amd64" ]
then
        sudo chroot ./mnt rm etc/apt/sources.list
        sudo chroot ./mnt bash -c 'echo "deb http://ftp.ubuntu.com/ubuntu jammy  main universe restricted" > etc/apt/sources.list'
        sudo chroot ./mnt bash -c 'echo "deb http://ftp.ubuntu.com/ubuntu jammy-security  main" >> etc/apt/sources.list'
        sudo chroot ./mnt bash -c 'echo "deb http://ftp.ubuntu.com/ubuntu jammy-updates  main universe restricted" >> etc/apt/sources.list'
else
        sudo chroot ./mnt rm etc/apt/sources.list
        sudo chroot ./mnt bash -c 'echo "deb http://ports.ubuntu.com/ubuntu-ports jammy  main universe restricted" > etc/apt/sources.list'
        sudo chroot ./mnt bash -c 'echo "deb http://ports.ubuntu.com/ubuntu-ports jammy-security  main" >> etc/apt/sources.list'
        sudo chroot ./mnt bash -c 'echo "deb http://ports.ubuntu.com/ubuntu-ports jammy-updates  main universe restricted" >> etc/apt/sources.list'
fi
sudo chroot ./mnt bash -c 'echo "/dev/sda / ext4 errors=remount-ro,acl 0 1" > etc/fstab'
sudo chroot ./mnt apt update
sudo mount -o bind /proc mnt/proc
sudo mount -o bind /dev mnt/dev
sudo mount -o bind /sys mnt/sys
sudo mkdir ./mnt/boot/efi
sudo mount ${mydev}p1 ./mnt/boot/efi
sudo chroot ./mnt bash -c 'apt -y install initramfs-tools'
sudo chroot ./mnt bash -c 'apt -y update'
if [ "$arch" == "amd64" ]
then
        sudo chroot ./mnt bash -c 'apt -y install grub-efi-amd64 git memtester python3 python3-pip python3.10-venv'
else
        sudo chroot ./mnt bash -c 'apt -y install grub-efi-arm64 git memtester python3 python3-pip python3.10-venv'
fi
kernelLink=`readlink ./mnt/boot/vmlinuz`
initrdLink=`readlink ./mnt/boot/initrd.img`
cpwd=`pwd`
device=`df | grep -i $cpwd | awk '{ print $1}' | head -1`
deviceefi=`df | grep -i $cpwd | awk '{ print $1}' | tail -1`
rootfsblkid=`sudo blkid -p $device | awk '{ print $2}' | sed 's/\"//g' | sed 's/UUID=//'`
efiblkid=`sudo blkid -p $deviceefi | awk '{ print $3}' | sed 's/\"//g' | sed 's/UUID=//'`
echo "======================================================================="
echo $rootfsblkid $efiblkid
echo "======================================================================="
sudo chroot ./mnt bash -c "echo \"/dev/disk/by-uuid/$rootfsblkid / ext4 ro,defaults 0 0\"  > etc/fstab"
sudo chroot ./mnt bash -c "echo \"/dev/disk/by-uuid/$efiblkid /boot/efi vfat ro,defaults 0 0\" >> etc/fstab"
sudo chroot ./mnt bash -c "update-initramfs -k all -c"
( cat grub.cfg | sed "s/INITRD/\/boot\/$initrdLink/" | sed "s/KERNEL/\/boot\/$kernelLink root=UUID=$rootfsblkid/" | sed "s/ROOTFS/$rootfsblkid/g" | sed "s/root=/init=\/sbin\/overlay.sh root=/" ) > grub.cfg.final
# use the UUID from the FS
( cat load.cfg | sed "s/ROOTFS/$rootfsblkid/g" ) > load.cfg.final
sudo cp grub.cfg.final mnt/boot/grub/grub.cfg
sudo cp ./overlay.sh mnt/sbin
sudo chmod 755 mnt/sbin/overlay.sh
sudo mkdir mnt/boot/grub/x86_64-efi/
sudo cp load.cfg.final mnt/boot/grub/x86_64-efi/load.cfg
if [ "$arch" == "amd64" ]
then
        sudo chroot ./mnt bash -c 'grub-install --efi-directory=/boot/efi --no-uefi-secure-boot --target=x86_64-efi --no-nvram --modules="ext2 part_gpt" dummy'
else
        sudo chroot ./mnt bash -c 'grub-install --efi-directory=/boot/efi --no-uefi-secure-boot --target=arm64-efi --no-nvram --modules="ext2 part_gpt" dummy'
fi

# We need to configure the system now

sudo chroot ./mnt bash -c 'echo "OpenBMCtest" > /etc/hostname'
# default root password
sudo chroot ./mnt bash -c 'echo "root:0penBmc" | chpasswd'
sudo chroot ./mnt bash -c 'cd /root ; git clone https://github.com/opencomputeproject/ocp-diag-memtester.git ; cd ocp-diag-memtester ; python3 -m venv . ; source bin/activate ; pip install -r requirements.txt'
sudo chroot ./mnt bash -c 'echo "NAutoVTs=6" >> /etc/systemd/logind.conf'
sudo chroot ./mnt bash -c 'echo "ReserveVT=7" >> /etc/systemd/logind.conf'
sudo chroot ./mnt bash -c 'mkdir /etc/systemd/system/getty@tty1.service.d/'
sudo cp override.conf ./mnt/etc/systemd/system/getty@tty1.service.d/
sudo chroot ./mnt bash -c 'echo "cd ocp-diag-memtester" >> /root/.profile'
sudo chroot ./mnt bash -c 'echo "source bin/activate" >> /root/.profile'
sudo chroot ./mnt bash -c 'echo "python3 src/main.py --mt_args=\"100M 3\"" >> /root/.profile'
sudo chroot ./mnt bash -c 'mkdir /rw; chmod 777 /rw'
sudo umount mnt/sys
sudo umount mnt/dev
sudo umount mnt/proc
sudo umount mnt/boot/efi
sudo umount mnt
sudo losetup -d $mydev
gzip linux_$arch.img
ls -lta linux_$arch.img.gz
exit 0
