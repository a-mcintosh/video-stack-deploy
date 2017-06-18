#!/bin/bash -ex

# build a usb installer: debian, preseed, ansible

# $1 - dev of usb stick to clobber (like sdc, no /dev/ prefex)
dev=$1

# Do this:
# 1. sudo apt install git pmount dcfldd
# 2. clone this repo
# 3. adjust ansible inventory file, commit and push back to public repo
# 4. adjust this script (maybe, see below)
# 5. run it:
# ./mk_usb_installer.sh sdb
# it will do this:
#  a. setup bootable usb stick
#  b. run a web server to serve up the preseed, early, late_command.sh

# 6. boot target machine from stick.  It will do this:
#  a. install the OS
#  b. wget/run late_command.sh
#  c. late_command.sh will clone the repo and run
#  d. ansible --local --limit=$(hostname)


# things that may need tweeking:

# preseed - how the installer gets the file (defaults to http from this box)
# preseed.cfg d-i preseed/late_command - gets/runs late_command.sh
# late_command.sh - gets ansible playbook

# To install to a target other than /dev/sda
# install full desktop
# appends='partman-auto\/disk=\/dev\/nvme0n1 tasks=ubuntu-desktop'


# use the supplied ./http_server.sh
preseed="url=$(hostname):8000"

# or depending on local dns:
# preseed="url=$(hostname).local:8000"

# host the file on some other server hostname dc10b.
# your problem to setup the server, hostname whatever you want.
# preseed="url=dc10b"

# to use the file on the usb stick
# preseed may need to be adjusted to get from install media.
# preseed="file=preseed.cfg"

# per box changes can be done by passing parameter to the kernel
# from the syslinux on the usb stick:
# example: to install to an SSD that doesn't come up as /dev/sda:
# (don't forget to escape the slasses because bash)
# appends='partman-auto\/disk=\/dev\/nvme0n1'

# where to get what:

# suite=stretch
# bootimg_loc=http://ftp.debian.org/debian/dists/${suite}/main/installer-amd64/current/images
# iso=debian-stretch-DI-rc3-amd64-netinst.iso
# iso_loc=http://cdimage.debian.org/cdimage/stretch_di_rc3/amd64/iso-cd

suite=xenial
# bootimg_loc=http://archive.ubuntu.com/ubuntu/dists/${suite}/main/installer-amd64/current/images/
bootimg_loc=http://archive.ubuntu.com/ubuntu/dists/${suite}-updates/main/installer-amd64/current/images/
iso=ubuntu-16.04.2-server-amd64.iso
iso_loc=http://releases.ubuntu.com/${suite}

# The rest should just work.

# get and veriy the boot image
# (hd-media dir because that is bunred into the SHA256SUMS file)
wget -N --directory-prefix hd-media ${bootimg_loc}/hd-media/boot.img.gz
curl -OJ ${bootimg_loc}/SHA256SUMS
# pull the line out for the 1 file and verify it
grep hd-media/boot.img.gz SHA256SUMS > boot.img.gz.SHA256SUM
sha256sum --check boot.img.gz.SHA256SUM

# cd of local .deb's
wget -N ${iso_loc}/${iso}
curl -OJ ${iso_loc}/SHA256SUMS
grep ${iso} SHA256SUMS > ${iso}.SHA256SUM
sha256sum --check ${iso}.SHA256SUM

zcat hd-media/boot.img.gz|sudo dcfldd of=/dev/${dev}
# or good ol dd
# zcat boot.img.gz|sudo dd of=/dev/${dev} conv=fdatasync

# make room for the 800mb ubuntu iso
# sudo fatresize -p -s 2G /dev/${dev}

pmount /dev/${dev}

# append appends to append, preseed location too.
# tee so I can see what gets written out.
sed "/^APPEND/s/$/ fb=false ${preseed} ${appends}/" syslinux.cfg | tee /media/${dev}/syslinux.cfg

# bail here becuase the ubuntu iso doen't fit
pumount /dev/${dev}
exit

# copy the preseed files in case of problems serving them over the net.
# 'just' fis the APPAND line and the early/late stuff and off you go.
cp -a d-i/${suite}/* /media/${dev}

# this doesn't work for Ubuntu.
# The .iso is too big and sometimes boot is an iso9660 fs so RO?!!
# boot.img only has 782M of free space.
# so put it on a 2nd usb stick, or the unused space on the 8gig usb stick.
cp ${iso} ${iso}.SHA256SUM /media/${dev}

cd /media/${dev}

# check the iso image again, make sure it copied ok.
sha256sum --check ${iso}.SHA256SUM

cd -
pumount /dev/${dev}

./http_server.sh