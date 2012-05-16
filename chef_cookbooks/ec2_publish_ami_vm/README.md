Description
===========

A chef cookbook to setup a VM on EC2/Openstack where the recloud.sh script can
be executed.

Requirements
============

A properly configured knife ec2.
A chef-server or chef-solo setup.

Attributes
==========

Usage
=====

Upload to your chef-server

    knife cookbook upload ec2_publish_ami_vm

Launch a VM on ec2

    EC2_REGION='ap-southeast-1'
    codename=precise
    arch2=amd64
    amisurl=http://uec-images.ubuntu.com/query/$codename/server/released.current.txt
    UBUNTU_AMI=$(wget -qO- $amisurl | egrep "ebs.$arch2.$EC2_REGION.*paravirtual" | cut -f8)
    [ -z "$UBUNTU_AMI" ] && echo "can't find the AMI to use" && exit 1
    SIZE=30
    knife ec2 server create -I $UBUNTU_AMI -f m1.medium -x ubuntu -d ubuntu-12.04-gems -i $EC2_KEYPAIR_PEM -r "recipe[ec2_publish_ami_vm]" -G http-https-ssh-smtp-vmreg -N ec2-ubuntu-new --region $EC2_REGION --availability-zone ${EC2_REGION}b --ebs-size $SIZE --no-host-key-verify --environment intalio-CF

Launch a VM on HP cloud.

    Todo.

