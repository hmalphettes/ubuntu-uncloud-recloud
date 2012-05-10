# This file should be sourced.
# Environmental values in Open-Stack
# No secrets here.
# No need to execute this more than once.
[ -z "$codename" ] && export codename=oneiric
[ -z "$arch" ] && export arch=x86_64
[ -z "$arch2" ] && export arch2=amd64
[ -z "$size" ] && export size=10 #G

export amisurl=http://uec-images.ubuntu.com/query/$codename/server/released.current.txt
export zoneurl=http://instance-data/latest/meta-data/placement/availability-zone
export zone=$(wget -qO- $zoneurl)
export region=$(echo $zone | perl -pe 's/.$//')
[ -z "$region" ] && echo "Could not read the current region. That is a blocker." && exit 1

export EC2_URL="https://ec2.$region.amazonaws.com"
export instanceid=$(wget -qO- http://instance-data/latest/meta-data/instance-id)
[ -z "$instanceid" ] && echo "Can't read the instance-id. That is a blocker" && exit 1
export akiid=$(wget -qO- $amisurl | egrep "ebs.$arch2.$region.*paravirtual" | cut -f9)
export ariid=$(wget -qO- $amisurl | egrep "ebs.$arch2.$region.*paravirtual" | cut -f10)

# Check that all the ec2 secrets necessary are defined.
[ -z "$ec2_keys_dir" ] && export ec2_keys_dir="~/.ec2"
[ -z "$EC2_CERT" ] && export EC2_CERT=$(echo $HOME/.ec2/cert-*.pem)
if [ -z "$EC2_CERT" ]; then
  echo "EC2_CERT undefined; Can't find a $HOME/.ec2/cert-*.pem"
  exit 13
fi
[ -z "$EC2_PRIVATE_KEY" ] && export EC2_PRIVATE_KEY=$(echo $HOME/.ec2/pk-*.pem)
if [ -z "$EC2_PRIVATE_KEY" ]; then
  echo "EC2_PRIVATE_KEY undefined; Can't find a $HOME/.ec2/pk-*.pem"
  exit 13
fi
aws_missing_key="AWS_USERID='$AWS_USERID'\nAWS_ACCESSKEY='$AWS_ACCESSKEY'\nAWS_SECRETKEY='$AWS_SECRETKEY'"
[ -z "$AWS_USERID" ] && echo "AWS_USERID not defined" && exit 13
[ -z "$AWS_ACCESSKEY" ] && echo "AWS_ACCESSKEY not defined" && exit 13
[ -z "$AWS_SECRETKEY" ] && echo "AWS_SECRETKEY not defined" && exit 13

[ -z "$imageurl" ] && echo "Undefined imageurl; Missing the URL of the VM image (or zip or tar.gz of it) to publish as an AMI." && exit 14
