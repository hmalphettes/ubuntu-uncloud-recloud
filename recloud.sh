#!/bin/bash
__dirname=$(dirname `readlink -f $0`)
source $__dirname/lib/env.sh

export now=`date +%Y%m%d-%H`

imagefilename=$(basename $imageurl)
base_imagefilename=$imagefilename
imagefilename=${imagefilename%.*}
echo "base_imagefilename: $base_imagefilename"
echo "imagefilename: $imagefilename"
# by default the type of the VM file is a vmdk.
# .raw and .img and .cow2 are other possible types.
[ -z "$img_file_extension" ] && img_file_extension=vmdk
[ -z "$build_folder" ] && build_folder=$HOME/publish_build
already_present_vmfile=`find $build_folder -type f -name *.$img_file_extension`
if [ -n "already_present_vmfile" -a -f "$already_present_vmfile" ]; then
  echo "Found the VM file  $already_present_vmfile. Use it? (default yes)"
  read response
  if [ -z "$response" ]; then
    vm_imagefile=$already_present_vmfile
  else
    echo "Will unzip or re-download then"
  fi
fi
if [ -z "$vm_imagefile" ]; then
    mkdir -p $build_folder

    if [ -n "$(echo $base_imagefilename | grep .tar)" ]; then
      imagefilename=${imagefilename%.*}
    elif [ -n "$(echo $base_imagefilename | grep .zip)" ]; then
      imagefile_iszip=true
      imagefilename=${imagefilename%.*}
    fi
    if [ ! -f "$build_folder/$imagefilename" ]; then
      if [ -f "$build_folder/$base_imagefilename" ]; then
        echo "Unzip the existing download $base_imagefilename ? (default yes)"
        read response
        if [ -n "$response" ]; then
          do_download=true
        else
          if [ -n "$imagefile_iszip" ]; then
            rm -rf $build_folder/*
            unzip $build_folder/$base_imagefilename -d $build_folder
          else
            tar -zxvf $build_folder/$base_imagefilename -C $build_folder
          fi
        fi
      else
          echo "Could not find the downloaded VM $imagefilename"
          echo "Download from $imageurl? (default yes)"
          read response
          if [ -z "$response" ]; then
            do_download=true
          else
            echo "No vm image to publish; Bye!"
            exit 1
          fi
      fi
    else
      echo "$build_folder/$imagefilename exists, skip download and reuse? (default yes)"
      read response
      if [ -n "$response" ]; then
        echo "Override and download again"
        do_download=true
      fi
    fi
    if [ -n "$do_download" ]; then
      rm -rf $build_folder/*
      echo "Downloading, this could take a while"
      if [ -n "$(echo $base_imagefilename | grep .zip)" ]; then
        #wget $imageurl
        curl -o $build_folder/$base_imagefilename $imageurl
        unzip $build_folder/$imagefilename -d $build_folder
      else
        wget -O- $imageurl | tar vxzf - -C $build_folder
      fi
    fi
    already_present_vmfile=`find $build_folder -type f -name *.$img_file_extension`
    if [ -n "already_present_vmfile" -a -f "$already_present_vmfile" ]; then
      echo "Found the VM file  $already_present_vmfile. Use it? (default yes)"
      read response
      if [ -z "$response" ]; then
        vm_imagefile=$already_present_vmfile
      else
        echo "Unexpected vm file found. Bye!"
        exit 1
      fi
    else
      echo "No *.$img_file_extension found in $build_folder. Bye!"
      exit 1
    fi
fi

# transform the vmdk into a raw image if necessary
vm_image_actual_file_extension=`echo ${vm_imagefile#*.}`
if [ "vmdk" = "$vm_image_actual_file_extension" ]; then
  if [ ! -f "$vm_imagefile.raw" ]; then
    echo "Make a raw disk from the vmdk $vm_imagefile"
    echo "This process can take 10 minutes. To make sure it is alive, use top on a separate terminal and look for VBoxSVC to be an active process:"
    #VBoxManage convertfromraw --format VMDK $raw_file $vmdk_file
    #qemu-img convert -O raw $vm_imagefile $vm_imagefile.raw
    VBoxManage clonehd -format RAW $vm_imagefile $vm_imagefile.raw
    if [ "$?" != "0" ]; then
      echo "Error converting the vmdk into a raw image"
      exit 1
    fi
  else
    echo "Reuse the existing raw image $vm_imagefile.raw"
  fi
  vm_imagefile="$vm_imagefile.raw"
fi
imagedir=$HOME/mnt_downloaded_vm
if [ -d $imagedir ]; then
  mounted=$(df -h | grep $imagedir)
  if [ -n "$mounted" ]; then
    echo "$imagedir is already mounted: $mounted"
    echo "Umount (default yes)?"
    read response
    if  [ -z "$response" ]; then
      sudo umount $imagedir
    else
      dont_mount=true
      echo "Continuing with the existing mounted directory and its content then."
    fi
  fi
fi
if [ ! -d $imagedir ]; then
  mkdir $imagedir
fi


if [ -z "$dont_mount" ]; then
  echo "Mounting $imagefilename in $imagediri with $__dirname"
  #$__dirname/lib/loop-mnt.sh $build_folder/$imagefilename $imagedir

    # mount the image:
    sudo umount $imagedir || true
    sudo qemu-nbd -d /dev/nbd0 || true

    # make sure there is nothing in the mounted directory
    dir_nb=`ls $imagedir -1 | wc -l`
    if [ "$dir_nb" != "0" ]; then
      echo "The directory where the vm will be mounted is not empty. Bye!"
      exit 1
    fi
    sudo modprobe nbd max_part=8
    sudo qemu-nbd -c /dev/nbd0 $vm_imagefile
    sudo mount /dev/nbd0p1 $imagedir
    # make sure that we find the expected typcial linux file
    if [ "$?" != "0" ]; then
      echo "Unable to mount the disk: something happened"
      exit 1
    fi
fi

# Uncloud
sudo $__dirname/lib/recloud-mounted-img.sh $imagedir
if [ "$?" != "0" ]; then
  echo "The script to manipulate the vm exitted with status $?"
  echo "Stop now? (default yes)"
  read response
  if [ -z "$response" ]; then
    echo "Bye"
    exit 1
  fi
  echo "Continue anyways"
fi

# manual extra changes
echo "The disk is mounted in $imagedir. do what you must (manual changes) then press enter to continue."
read response
if [ -n "$response" ]; then
  echo "bye then the disk is still mounted."
  exit 1
fi


dev=/dev/xvdi
if [ ! -e "$dev" ]; then
  echo "no mounted ebs volume create a new one with size ${size}G ? (default yes)"
  read response
  if [ -z "$response" ]; then
    volumeid=$(ec2-create-volume --size $size --availability-zone $zone | cut -f2)
    echo "created EBS volumentid $volumeid"
    if [ -z "$volumeid" ]; then
      echo "Failed to create the ebs volume; the volumeid was not returned"
      exit 1
    fi
  else
    echo "Enter the ebs volumeid ? (default $volumeid)"
    read response
    if [ -n "$response" ]; then
      volumeid=$response
    else
      echo "An ebs volume id is required; Bye!"
      exit 1
    fi
  fi
  ec2-attach-volume --device /dev/sdi --instance "$instanceid" "$volumeid"
  while [ ! -e $dev ]; do
    sleep 3
    echo "waiting for the ebs volume to attach"
  done
  do_format=true
else
  echo "Reusing the attached volume on /dev/xvdi"
  echo "These are the attached volumes to this instance"
  attached=`ec2-describe-volumes --filter attachment.instance-id=$instanceid --filter attachment.device=/dev/sdi | grep attached`
  echo $attached
  if [ -z "$attached" ]; then
    echo "Cannot find the attached volume to the current instancef on /dev/sdi"
    exit 1
  fi
  volumeid=`echo $attached | sed "s/^ *//;s/ *$//;s/ \{1,\}/ /g" | cut -d ' ' -f2`
  if [ -z "$volumeid" ]; then
    echo "Cannot find the volumeid from $attached"
    exit 1
  fi
  echo "Got the volumeid $volumeid"
  echo "Format anew (default yes)"
  read response
  if [ -z "$response" ]; then
    do_format=true
  fi
fi
if [ -n "$do_format" ]; then
  [ -z "$vm_dd_format" ] && vm_dd_format="ext4"
  echo "Formatting $dev with $vm_dd_format"
  if [ "$vm_dd_format" = "xfs" ]; then
    sudo mkfs.xfs -L cloudimg-rootfs $dev
  else
    sudo mkfs.ext4 -L cloudimg-rootfs $dev
  fi
fi

ebsimagedir=$imagedir-ebs
if [ -d "$ebsimagedir" ]; then
  mounted=$(df -h | grep $ebsimagedir)
  if [ -n "$mounted" ]; then
    echo "$ebsimagedir is already mounted: $mounted"
    echo "Umount (default yes)?"
    read response
    if  [ -z "$response" ]; then
      sudo umount $ebsimagedir
    else
      ebs_dont_mount=true
      echo "Continuing with the existing ebs mounted directory and its content then."
    fi
  fi
fi
if [ ! -d "$ebsimagedir" ]; then
  sudo mkdir "$ebsimagedir"
fi
if [ -z "$ebs_dont_mount" ]; then
  echo "Mounting the ebs volume on $ebsimagedir"
  sudo mount $dev $ebsimagedir
fi

echo "$ebsimagedir contains already:"
ls $ebsimagedir

echo "Copying the contents of $imagedir into $ebsimagedir (default yes)?"
read response
if [ -z "$response" ]; then
  sudo tar -cSf - -C $imagedir . | sudo tar xvf - -C $ebsimagedir
else
  echo "Continuing with the content of $ebsimagedir then"
fi
echo "Everything good? We are about to unmount everything. (default yes go ahead)?"
read response
if [ -n "$response" ]; then
  echo "Bye for now"
  exit 0
fi
echo "Umounting the vmdisk and the ebs volume"
sudo umount $imagedir
sudo umount $ebsimagedir
echo "Detaching the ebs volume from this instance"
ec2-detach-volume "$volumeid"
while ec2-describe-volumes "$volumeid" | grep -q ATTACHMENT
  do sleep 3; done
echo "Take a snapshot of the ebs volume $volumeid ? (default yes)"
read response
if [ -z "$response" ]; then
  snapshotid=$(ec2-create-snapshot --description "creating a new ami from $imagefilename" "$volumeid" | cut -f2)
  if [ -z "$snapshotid" ]; then
    echo "Unable to read $snapshotid we have a problem"
    exit 1
  fi
  echo "The snapshot of the ebs volume is $snapshotid"
else
  if [ -n "$volumeid" ]; then
    echo "snapshots available for this volume $volumeid"
    ec2-describe-snapshots --filter volume-id=$volumeid
  else
    echo "all snapshots available"
    ec2-describe-snapshots
  fi
  echo "Enter the id of the snapshot to use it starts with 'snap'"
  read response
  if [ -z "$response" ]; then
    echo "snapshot id required. bye"
    exit 1
  fi
fi

pending=$(ec2-describe-snapshots "$snapshotid" | grep pending)
while [ -n "$pending" ]; do
  # example:
  # SNAPSHOT        snap-5e19df25   vol-235fd14f    pending 2012-02-24T06:45:42+0000        15%     399959105998    10      creating a new ami from intalio_aws_9G-1.0.0.327.raw
  # SNAPSHOT  snap-b8c053d4   vol-37a4d854    pending 2012-05-18T03:47:02+0000        95      399959105998    20      creating a new ami from Intalio-Summer12-20120517
  progress=`echo "$pending" | sed "s/^ *//;s/ *$//;s/ \{1,\}/ /g" #| cut -d ' ' -f6`
  echo "DEBUGGING: pending => $pending"
  echo "Waiting for the snapshot to complete:"
  echo $pending
  echo "       progress (%): $progress"
  sleep 30
  pending=$(ec2-describe-snapshots "$snapshotid" | grep pending)
done
completed=$(ec2-describe-snapshots "$snapshotid" | grep completed)
if [ -z "$completed" ]; then
  echo "ec2-describe-snapshots \"$snapshotid\" should be 'completed' but we can't see that"
  ec2-describe-snapshots "$snapshotid"
  echo "Please debug this or wait until the snapshot is completed then continue or stop."
  echo "Stop now ? (default yes)"
  read response
  if [ -z "$response" ]; then
    exit 1
  fi
fi

[ -z "$name" ] && name="Intalio-$now"
[ -z "$description" ] && description="Intalio_on_EC2_at_$now_from_$imagefilename"

arch=x86_64
arch2=amd64
ephemeraldev=/dev/sdb

ec2_register_cmd="ec2-register \
 --name \"$name\" \
 --description \"$description\" \
 --architecture \"$arch\" \
 --kernel \"$akiid\" \
 --block-device-mapping $ephemeraldev=ephemeral0 \
 --snapshot \"$snapshotid\" \
 --private-key $EC2_PRIVATE_KEY --cert $EC2_CERT"
echo "About to register a new ami with"
echo "$ec2_register_cmd"
echo "Confirm? (default yes)"
read response
if [ -z "$response" ]; then
  ami_registered=true
  $amiid=$($ec2_register_cmd | cut -f2)
else
  echo "Not registering the VM"
fi

echo "Delete the ebs volume used to create the snapshot? $volumeid (default yes)"
read response
if [ -z "$response" ]; then
  ec2-delete-volume "$volumeid"
fi

if [ -n "$ami_registered" ]; then
cat <<EOF
AMI: $amiid $codename $region $arch2

ami id:       $amiid
aki id:       $akiid
region:       $region ($zone)
architecture: $arch ($arch2)
os:           Ubuntu $release $codename
name:         $name
description:  $description
EBS volume:   $volumeid (deleted)
EBS snapshot: $snapshotid
intalio_vm_disk:   $imagefilename

Test the new AMI using something like:

  export EC2_URL=http://ec2.$region.amazonaws.com
  ec2-run-instances --key \$USER --instance-type m1.large $amiid

EOF

fi
