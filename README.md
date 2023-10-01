Sync Boot Partition
===================

This utility will attempt to find disk partitions with the same UUID as /boot
and /boot/efi partitions. Once those partitions are found, it will sync content
of the currently mounted partitions onto their clones.

### Create GPT Partitions

#### Mirror existing disk

To create mirror partitions, you can use `sgdisk`:

    sgdisk /dev/disk1 -R /dev/disk2

#### Copy UUID

Alternatively, you can use `gdisk` to adjust UUID of the existing partition:

1. Find existing partition UUID:

```sh
sgdisk -i <partnum> <device>
```

2. Run `gdisk`:

```sh
gdisk <device>
```

3. Go to expert mode by typing `x`.

4. Use change command by typing `c`, selecting the partition number, and writing desired UUID.

5. Use write command by typing `w`.
