default[:deployment][:user] = "ubuntu"
default[:deployment][:group] = "ubuntu"

default[:recloud][:arch] = "x86_64"
default[:recloud][:arch2] = "amd64"
default[:recloud][:ubuntu_codename] = "oneiric"
default[:recloud][:aws_userid] = ""
default[:recloud][:aws_accesskey] = ""
default[:recloud][:aws_secretkey] = ""
default[:recloud][:ec2_keys_dir] = "$HOME/.ec2"
# size of the EBS volume in which the VM is copied
default[:recloud][:ebs_size_G] = "20"

default[:recloud][:script][:installation_folder] = "/home/ubuntu/ubuntu-uncloud-recloud"
default[:recloud][:script][:repo] = "https://github.com/hmalphettes/ubuntu-uncloud-recloud.git"
default[:recloud][:script][:branch] = "master"


