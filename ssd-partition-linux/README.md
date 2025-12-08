## Split SSD: small OS + big /data

A very good guide can be found [here](https://linuxconfig.org/how-to-partition-a-drive-on-linux).

Goal: keep / (root) ~100 GB for the OS, and use the rest as /data. <br />
Because our current root is on the SSD, we can’t shrink it while mounted. 
The easiest way is to boot temporarily from another device, then modify the SSD offline.

I assume that currently we have an SD card that contains the boot files and SSD that contains the OS.
ALso, we have another USB drive that contains a full OS.

### 1) Boot from your USB stick OS
```bash
lsblk # list block devices > it shows all block storage devices connected to our system
```
Example output:
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0    2G  0 loop 
sda      8:0    0  3.6T  0 disk 
|-sda1   8:1    0  511M  0 part 
`-sda2   8:2    0  3.6T  0 part 
sdb      8:16   1 57.3G  0 disk 
|-sdb1   8:17   1  512M  0 part /boot/firmware
`-sdb2   8:18   1 56.8G  0 part /
zram0  254:0    0    2G  0 disk [SWAP]
```

What I did:
```
$ sudo parted /dev/sda
GNU Parted 3.6
Using /dev/sda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) unit MiB                                                         
(parted) print                                                            
Model: SABRENT  (scsi)
Disk /dev/sda: 3815448MiB
Sector size (logical/physical): 4096B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start    End         Size        File system  Name     Flags
 1      1.00MiB  512MiB      511MiB      fat32        primary  boot, esp
 2      512MiB   3815448MiB  3814936MiB  ext4         primary

(parted) resizepart 2 124928                                              
Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
Yes/No? yes                                                               
(parted) print                                                            
Model: SABRENT  (scsi)
Disk /dev/sda: 3815448MiB
Sector size (logical/physical): 4096B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start    End        Size       File system  Name     Flags
 1      1.00MiB  512MiB     511MiB     fat32        primary  boot, esp
 2      512MiB   124928MiB  124416MiB  ext4         primary

(parted) quit                                                             
Information: You may need to update /etc/fstab.

pi5@raspberrypi:~ $ sudo e2fsck -f /dev/sda2                              
e2fsck 1.47.2 (1-Jan-2025)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
rootfs: 138245/7864320 files (0.1% non-contiguous), 2540663/31457280 blocks
pi5@raspberrypi:~ $ sudo resize2fs /dev/sda2
resize2fs 1.47.2 (1-Jan-2025)
Resizing the filesystem on /dev/sda2 to 31850496 (4k) blocks.
The filesystem on /dev/sda2 is now 31850496 (4k) blocks long.

pi5@raspberrypi:~ $ sudo parted /dev/sda --script unit MiB mkpart primary ext4 124928 100%
pi5@raspberrypi:~ $ sudo parted /dev/sda unit MiB print
Model: SABRENT  (scsi)
Disk /dev/sda: 3815448MiB
Sector size (logical/physical): 4096B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start      End         Size        File system  Name     Flags
 1      1.00MiB    512MiB      511MiB      fat32        primary  boot, esp
 2      512MiB     124928MiB   124416MiB   ext4         primary
 3      124928MiB  3815447MiB  3690519MiB               primary

pi5@raspberrypi:~ $ sudo mkfs.ext4 -L data /dev/sda3
mke2fs 1.47.2 (1-Jan-2025)
Creating filesystem with 944772864 4k blocks and 236199936 inodes
Filesystem UUID: 985899fe-303c-4298-bc46-c92835fd8d30
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208, 
	4096000, 7962624, 11239424, 20480000, 23887872, 71663616, 78675968, 
	102400000, 214990848, 512000000, 550731776, 644972544

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (262144 blocks): done
Writing superblocks and filesystem accounting information: done       

pi5@raspberrypi:~ $ sudo mkdir -p /mnt/data
pi5@raspberrypi:~ $ sudo mount /dev/sda3 /mnt/data
pi5@raspberrypi:~ $ df -h /mnt/data
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda3       3.5T  2.1M  3.3T   1% /mnt/data
pi5@raspberrypi:~ $ sudo umount /mnt/data
pi5@raspberrypi:~ $ sudo mkdir -p /mnt/ssdroot
pi5@raspberrypi:~ $ sudo mount /dev/sda2 /mnt/ssdroot
pi5@raspberrypi:~ $ DATA_UUID=$(sudo blkid -s UUID -o value /dev/sda3); echo "$DATA_UUID"
985899fe-303c-4298-bc46-c92835fd8d30
pi5@raspberrypi:~ $ sudo cp /mnt/ssdroot/etc/fstab /mnt/ssdroot/etc/fstab.bak
pi5@raspberrypi:~ $ echo "UUID=${DATA_UUID}  /data  ext4  defaults,noatime  0  2" | sudo tee -a /mnt/ssdroot/etc/fstab
UUID=985899fe-303c-4298-bc46-c92835fd8d30  /data  ext4  defaults,noatime  0  2
pi5@raspberrypi:~ $ sudo mkdir -p /mnt/ssdroot/data
pi5@raspberrypi:~ $ sudo umount /mnt/ssdroot
pi5@raspberrypi:~ $ lsblk -f
NAME   FSTYPE FSVER LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
loop0  swap   1                                                                
sda                                                                            
|-sda1 vfat   FAT32 BOOT   5385-8525                                           
|-sda2 ext4   1.0   rootfs ff4d0a05-d0c0-4498-af62-180f3e73f265                
`-sda3 ext4   1.0   data   985899fe-303c-4298-bc46-c92835fd8d30                
sdb                                                                            
|-sdb1 vfat   FAT32 bootfs 1C94-4EC3                               436M    15% /boot/firmware
`-sdb2 ext4   1.0   rootfs f0abac56-08be-42e2-8726-9baa083e8685   49.7G     7% /
zram0  swap   1     zram0  a48efb09-3e47-4a80-b6e5-80c6087adca4                [SWAP]
```