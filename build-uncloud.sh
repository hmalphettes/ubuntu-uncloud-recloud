#!/bin/bash
if [ -n "$1" -a -s "$1" ];then
  echo "Using the image file $1"
  qcow2_file=$1
else
  qcow2_file=$(ls `pwd`/*.img)
  if [ ! -s "$qcow2_file" ]; then
	  echo "Download latest ubuntu? (default yes)"
    read response
    if [ -n "$response" ]; then
      echo "Bye then!"
      exit 1
    fi
    wget http://uec-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img
    qcow2_file=$(ls `pwd`/*.img)
    if [ ! -s "$qcow2_file" ]; then
      echo "Error downloading. Bye!"
      exit 1
    fi
  fi
fi
file=${qcow2_file%.*}
raw_file=$file.raw
if [ -s "$raw_file" ]; then
  echo "Raw file $raw_file exists already. Use it? (default yes)"
  read response
  if [ -n "$response" ]; then
    rm $raw_file
  fi
fi
if [ ! -s "$raw_file" ]; then
  echo "Convert $qcow2_file in raw formal"
  qemu-img convert -O raw $qcow2_file $raw_file
fi
size_bytes=`qemu-img info $raw_file | grep virtual\ size | sed  's/(/&\n/;s/.*\n//;s/ bytes)/\n&/;s/\n.*//'`
if [ -z "$size_bytes" ]; then
  echo "Could not read the size of the vm disk"
  exit 1
fi
size_G=$[$size_bytes/(1024*1024*1024)]
echo $size_G
[ -z "$SIZE"] && SIZE=15
if [ "$SIZE" != "$size_G" ]; then
  qemu-img resize $raw_file ${SIZE}G
  size_bytes=`qemu-img info $raw_file | grep virtual\ size | sed  's/(/&\n/;s/.*\n//;s/ bytes)/\n&/;s/\n.*//'`
  size_G=$[$size_bytes/(1024*1024*1024)]
  if [ "$SIZE" != "$size_G" ]; then
    echo "Could not resize the vm file"
    exit 1
  fi
  echo "Resized the virtual disk. Will need to grow the partition."
  do_resize_partition=true
fi


# mount the image:
mnt=`pwd`/mnt
mkdir -p $mnt
sudo umount mnt || true
sudo qemu-nbd -d /dev/nbd0 || true
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 $raw_file

# Resize if necessary the partition
if [ -n "$do_resize_partition" ]; then
  sudo e2fsck -f -y -v /dev/nbd0p1
  partition_start=`sudo fdisk -l /dev/nbd0 | grep /dev/nbd0p1 | awk '{print $2}'`
  [ "*" = "$partition_start" ] && partition_start=`sudo fdisk -l /dev/nbd0 | grep /dev/nbd0p1 | awk '{print $3}'`
  # fdisk script: delete partition; new partition; primary; partition #1; 
  #               start sector; end sector (default is max); write and exit
  echo "Rewriting the partition table to grow the size. partition_start $partition_start (continue?)"
  read response
  sudo fdisk /dev/nbd0 << EOF
d
n
p
1
$partition_start

w
EOF
  echo "Resized partition is: "
  sudo fdisk -l /dev/nbd0
  echo "Continue ?"
  read response
  sudo e2fsck -f -y -v /dev/nbd0p1
  sudo resize2fs /dev/nbd0p1

fi

sudo mount /dev/nbd0p1 $mnt

# Uncloud
sudo `pwd`/lib/uncloud-mounted-img.sh $mnt

# manual extra changes
echo "The disk is mounted in $mnt. do what you must (manual changes) then press enter to continue."
read response
if [ -n "$response" ]; then
  echo "bye then the disk is still mounted."
  exit 1
fi


# Unmount and disconnect device:
sudo umount $mnt
sudo qemu-nbd -d /dev/nbd0

# prepare a virtualbox appliance?
vmdk_file=${file}_unclouded.vmdk
if [ -s "$vmdk_file" ]; then
  echo "$vmdk_file exists already. reuse ? (default yes)"
  read response
  if [ -n "$response" ]; then
    rm $vmdk_file
  fi
fi
if [ ! -s "$vmdk_file" ]; then
  echo "Converting from raw to vmdk $vmdk_file"
  VBoxManage convertfromraw --format VMDK $raw_file $vmdk_file
fi
