#!/bin/sh
# 
# Copyright (c) 2024 Hewlett-Packard Development Company, L.P.
# Copyright (c) 2024 Open Compute Project
# MIT based license

mount -t tmpfs tmpfs /rw
mkdir /rw/.wdetc
mkdir /rw/.wdroot
mkdir /rw/.wdtmp
mkdir /rw/.wdlog
mkdir /rw/.wdlib
mkdir /rw/root
mkdir /rw/etc
mkdir /rw/tmp
mkdir /rw/log
mkdir /rw/lib
mount -t overlay overlay -o lowerdir=/etc,upperdir=/rw/etc,workdir=/rw/.wdetc /etc
mount -t overlay overlay -o lowerdir=/root,upperdir=/rw/root,workdir=/rw/.wdroot /root
mount -t overlay overlay -o lowerdir=/tmp,upperdir=/rw/tmp,workdir=/rw/.wdtmp /tmp
mount -t overlay overlay -o lowerdir=/var/log,upperdir=/rw/log,workdir=/rw/.wdlog /var/log
mount -t overlay overlay -o lowerdir=/var/lib,upperdir=/rw/lib,workdir=/rw/.wdlib /var/lib
exec /sbin/init
