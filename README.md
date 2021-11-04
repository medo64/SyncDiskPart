Sync Boot Partition
===================

This utility will attempt to find disk partitions with the same UUID as /boot
and /boot/efi partitions. Once those partitions are found, it will sync content
of the currently mounted partitions onto their clones.

To create mirror partitions, you can use sgdisk:

    sgdisk /dev/disk1 -R /dev/disk2
