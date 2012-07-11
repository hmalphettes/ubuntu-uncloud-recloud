# Uncloud / Recloud
Ubuntu cloud images helper and EC2/Openstack AMI publisher

## Uncloud

Canonical provides a build of ubuntu setup for OpenStack Amazon EC2.
These VMs are configured to run on EC2, consumes the EC2 init parameters and more.

More info: [Canonical's cloud portal](http://cloud.ubuntu.com).

To run those ubuntu builds on a local hypervisor, some changes are necessary.
The uncloud script runs through those changes.

## EC2-Recloud
Import an ubuntu VM archive into EC2 and publish it as an EBS based AMI.
A lot of this work is derived from Eric Hammond's blog post [Creating Public AMIs Securely for EC2](http://alestic.com/2011/06/ec2-ami-security), and his shell script [alestic-git-build-ami](https://github.com/alestic/alestic-git/blob/master/bin/alestic-git-build-ami).

Important note: this script assumes that the VM archive can be run by the EC2/Openstack hypervisor.
Potential pitfalls that this script does not resolve:
* the hypervisor does not understand the partition
* the kernel will panic (hint: use the 'virtual' build of the kernel)
* the runtime parameters passwed to the VM (ssh keys) are not taken into account by the VM (hint: apt-get install cloud-init)

This script is used at the moment with the a VM created from 'uncloud'.
That type of VM is originally made to run on EC2/Openstack. It works fine when re-imported into it.

# Uncloud
## Usage

    git clone http://github.com/hmalphettes/ubuntu-uncloud-recloud
    cd ubuntu-uncloud-recloud
    ./uncloud.sh

## Script description
- [Download the latest 12.04 cloud image](http://cloud-images.ubuntu.com/precise/current/)
- Clone it in the raw format
- Grow its partition from 2G to 15G
- Mount it locally
- Setup the ubuntu user with the ubuntu password via grub
- Disable the cloud-init service
- Clone the disk in vmdk format

Ready to be run in your favorite hypervisor.

## Requirements
- OS Linux; tested on ubuntu
- e2progs: e2fsck, resize2fs, fdisk
- qemu-img, qemu-nbd
- VBoxManage: vmdk conversion (optional)

# EC2-Recloud
## Usage

Define the EC2 keys as environment variables:

    AWS_USERID=""
    AWS_ACCESSKEY=""
    AWS_SECRETKEY=""

Define the URL of the Ubuntu VM archive to download as the environment varable

    imageurl=...

Place the pk-*.pem and cert-*.pem files in ~/.ec2
Check the script and run it:

    git clone http://github.com/hmalphettes/ubuntu-uncloud-recloud
    cd ubuntu-uncloud-recloud
    ./recloud.sh

## Description

1. Downoad the VM archive (if necessary)
2. Unzip it (if necessary
3. Locate the VM file (if necessary)
4. Clone the VM file into a raw VM file if the VM file is a vmdk (necessary for qemu-nbd).
5. Mount the VM file on the file system with qemu-nbd
6. Run the script lib/recloud-mounted-img.sh to reverse uncloud.
    - reset the grub config to a ubuntu cloud image
    - reset the ubuntu user's password
    - harden the /etc/sshd\_config to only accept public keys for authentication
    - delete the chef-connection parameters if present
    - delete the /home/ubuntu/.ssh/ keys and known\_hosts
    - wait for the user to manually tweak other things
7. Create a new EBS volume, attach it and mount it to the current instance.
8. Copy into the VM's content into the EBS volume.
9. Unmount everything
10. Create a snapshot of the EBS volument and publish it as an AMI.

## TODO
1- init job to lazy configure the sshd's keyx; just like cloud-init does but we are disabling it)
2- map 127.0.1.1 to the hostname (not a blocker)

