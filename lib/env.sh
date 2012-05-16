# This file should be sourced.
# Environmental values in Open-Stack
# No secrets here.
# No need to execute this more than once.

if [ -f $HOME/build_params.sh ]; then
  source $HOME/build_params.sh
fi

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

if [ -z "$AWS_USERID" ]; then
  echo "AWS_USERID not defined"
  echo "Enter AWS_USERID now. The format is 1111-2222-3333"
  read AWS_USERID
  export AWS_USERID
  aws_save=true
fi

if [ -z "$AWS_ACCESSKEY" ]; then
  echo "AWS_ACCESSKEY not defined"
  echo "Enter the AWS_ACCESSKEY now. The format is ABCDEFGHIKLMNOPQRSTU"
  read AWS_ACCESSKEY
  export AWS_ACCESSKEY
  aws_save=true
fi
if [ -z "$AWS_SECRETKEY" ]; then
  echo "AWS_SECRETKEY not defined"
  echo "Enter the AWS_SECRETKEY now. The format is 1Ab/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  read AWS_SECRETKEY
  export AWS_SECRETKEY
  aws_save=true
fi
if [ -z "$imageurl" ]; then
  echo "Undefined imageurl; Missing the URL of the VM image (or zip or tar.gz of it) to publish as an AMI."
  echo "Enter the URL to download the archive of the VM image (*.zip, *.tar.gz, *.vmd, *.qcow2, *.raw)"
  read imageurl
  aws_save=true
  export imageurl
fi

if [ -n "$aws_save" && -f "$HOME/build_params.sh" ]; then
  if [ -z "$AWS_USERID" -o -z "$AWS_ACCESSKEY" -o -z "$AWS_SECRETKEY" ]; then
    echo "Still missing an AWS key: AWS_USERID='$AWS_USERID'\nAWS_ACCESSKEY='$AWS_ACCESSKEY'\nAWS_SECRETKEY='$AWS_SECRETKEY'"
    exit 13
  fi
  echo "Save the settings in $HOME/build_params.sh (default yes, Y|N) ?"
  read response
  if [ -z "$response" -o "Y" == "$response" ]; then
    sed -i -e "s/^AWS_USERID=.*/AWS_USERID=$AWS_USERID/"
    sed -i -e "s/^AWS_SECRETKEY=.*/AWS_SECRETKEY=$AWS_SECRETKEY/"
    sed -i -e "s/^AWS_ACCESSKEY=.*/AWS_ACCESSKEY=$AWS_ACCESSKEY/"
    echo "saved"
  fi

fi

