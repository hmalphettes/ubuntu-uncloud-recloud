#!/bin/sh
sudo modprobe nbd max_part=8
BASEDIR=`readlink -f $(dirname $0)`
sudo qemu-nbd -vd /dev/nbd0p1 || true
echo "Connecting /dev/nbd0 to "$BASEDIR/../*.vmdk
sudo qemu-nbd -c /dev/nbd0 $BASEDIR/../*.vmdk
if [ -z "disable" ]; then
  echo "Delete the network udev file or update the macaddress if there is one"
  TDIR=`mktemp -d`
  sudo mount /dev/nbd0p1 $TDIR
  trap "{ cd - ; [ -d $TDIR ] && sudo umount $TDIR && rm -rf $TDIR && exit 255; }" SIGINT
  if [ -f "$TDIR/etc/udev/rules.d/70-persistent-net.rules" ]; then
    current_mc_address=`grep \"eth0\" /etc/udev/rules.d/70-persistent-net.rules | sed -n 's/^.*ATTR.address.==\"\([^\"]*\)\".*$/\1/p'`
    # we can either update the mac-address in the configuration file with the one we read here or
    # we can delete the file as well.
    #echo "Deleting the file."
    #sudo rm $TDIR/etc/udev/rules.d/70-persistent-net.rules
  fi
  sudo umount $TDIR
  rm -rf $TDIR
fi

echo "Starting the lxc 'myvminlxc'"
sudo lxc-start -n myvminlxc -f $BASEDIR/*.conf

