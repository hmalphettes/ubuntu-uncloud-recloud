#!/bin/bash
# Need to do a very few changes in the VM made to run on a local hypervisor
# to run on EC2

imagedir=$1
if [ -z "$imagedir" ]; then
  echo "Required a first argument that is the path to the root of the Linux OS to manipulate"
  exit 1
fi
if [ ! -d "$imagedir" ]; then
  echo "Expecting a directory as the first argument to the script. $1 does not exist"
  exit 1
fi
grub_cfg="$imagedir/boot/grub/grub.cfg"
if [ ! -f "$grub_cfg" ]; then
  echo "Can't find $grub_cfg"
  exit 1
fi

grub_default="$imagedir/etc/default/grub"
if [ ! -f "$grub_default" ]; then
  echo "Can't find $grub_default"
  exit 1
fi

echo "chroot and set the ubuntu user's password ? (default yes)"
read response
if [ -z "$response" ]; then
  echo "Enter the password for the ubuntu user (default 'ubuntu' no quotes)"
  read password
  password=`echo $password`
  [ -z "$password" ] && password="ubuntu"
  sudo chroot $imagedir sh -c "echo ubuntu:$password | chpasswd"
fi
[ -z "$password" ] && password="ubuntu"

# Remove the local uncloud arguments in grub:
# when we run the VM on a local hypervisor, we add some arguments
# to disable the cloud-init scripts. the linux line in /boot/grub/grub.cfg look like this:
# linux   /boot/vmlinuz-3.0.0-15-virtual root=UUID=79f92344-c2ff-4a19-a451-06134ec45279 ro init=/usr/lib/cloud-init/uncloud-init ds=nocloud  console=ttyS0
# we reset it to (don't change the kernel version etc):
# linux   /boot/vmlinuz-3.0.0-14-virtual root=LABEL=cloudimg-rootfs ro   console=ttyS0
# put back the root=LABEL (maybe not necessary)
sudo sed -i -e 's/^[[:space:]]*linux[[:space:]]*\(\/boot.*\) \(root=[^ ]*\) \(.*\)/        linux \1 root=LABEL=cloudimg-rootfs \3/g' $grub_cfg
#echo "sed exitted with $?"
# remove the uncloud-init and ds=nocloud
still=$(grep uncloud-init $grub_cfg)
if [ -z "$still" ]; then
  # let's insert it then; only on the first entry.
  sudo sed -i -e 's/root=LABEL=cloudimg-rootfs ro[[:space:]].*[[:space]]console=ttyS0/root=LABEL=cloudimg-rootfs ro  console=ttyS0/' $grub_cfg
  still=$(grep uncloud-init $grub_cfg)
  if [ -z "$still" ]; then
    echo "sed failed to insert 'uncloud-init' in $grub_cfg"
    grep uncloud-init $grub_cfg
    exit 1
  fi
fi

# do the same work on /etc/default/grub
# reset to GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0"
sudo sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0"/g' $grub_default
# and reset to GRUB_CMDLINE_LINUX=""
sudo sed -i -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=""/g' $grub_default

cloud_init="$imagedir/etc/init/cloud-init.conf"
if [ -f "$cloud_init.disabled" ]; then
  echo "Re-enabling $cloud_init"
  sudo mv $cloud_init.disabled $cloud_init
elif [ ! -f "$cloud_init" ]; then
  echo "Unable to find the cloud-init.conf in $imagedir/etc/init/cloud-init.conf"
  exit 1
fi

echo "Secure sshd: disable ssh except via public keys ?(default yes)"
read response
if [ -z "$response"]; then
  echo "UsePrivilegeSeparation yes; RSAAuthentication yes; PubkeyAuthentication yes; PasswordAuthentication no; UseLogin no; UsePAM no"
  sudo sed -i -e 's/^#*[[:space:]]*UsePrivilegeSeparation[[:space:]].*$/UsePrivilegeSeparation yes/' $imagedir/etc/ssh/sshd_config
  sudo sed -i -e 's/^#*[[:space:]]*RSAAuthentication[[:space:]].*$/RSAAuthentication yes/' $imagedir/etc/ssh/sshd_config
  sudo sed -i -e 's/^#*[[:space:]]*PubkeyAuthentication[[:space:]].*$/PubkeyAuthentication yes/' $imagedir/etc/ssh/sshd_config
  sudo sed -i -e 's/^#*[[:space:]]*PasswordAuthentication[[:space:]].*$/PasswordAuthentication no/' $imagedir/etc/ssh/sshd_config
  sudo sed -i -e 's/^#*[[:space:]]*UseLogin[[:space:]].*$/UseLogin no/' $imagedir/etc/ssh/sshd_config
  sudo sed -i -e 's/^#*[[:space:]]*UsePAM[[:space:]].*$/UsePAM no/' $imagedir/etc/ssh/sshd_config
fi

[ -f "$imagedir/home/ubuntu/.ssh/authorized_keys" ] && rm "$imagedir/home/ubuntu/.ssh/authorized_keys"
[ -f "$imagedir/home/ubuntu/.ssh/known_hosts" ] && rm "$imagedir/home/ubuntu/.ssh/known_hosts"
if [ -d "$imagedir/homeubuntu/.ssh" ]; then
  echo "$imagedir/home/ubuntu/.ssh is cleaned of authorized_keys and known_hosts. Delete it all together? (default yes)"
  read response
  [ -z "$response" ] && rm -rf $imagedir/home/ubuntu/.ssh
fi

if [ -d $imagedir/etc/chef ]; then
  echo "Delete the chef-server connection parameters: $imagedir/etc/chef/*.pem ?"
  read response
  if [ -z "$response" ]; then
    rm $imagedir/etc/chef/*.pem
  fi
fi

# for now
exit 0
