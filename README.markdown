# Ubuntu cloud images helper
## Ubuntu's cloud images
Canonical provides a build of ubuntu setup for OpenStack Amazon EC2.
These VMs are configured to run on EC2, consumes the EC2 init parameters and more.

More info: [Canonical's cloud portal](http://cloud.ubuntu.com).

## Uncloud the cloud images
To run those ubuntu builds on a local hypervisor, some changes are necessary.
The following script automates those changes.

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

## TODO
- Re-cloud: re-enable cloud-init, reset the ubuntu password, import on EC2 and publish as an AMI
- Export-from-ec2: create a vm disk from an ebs, uncloud, push to S3 for download.
