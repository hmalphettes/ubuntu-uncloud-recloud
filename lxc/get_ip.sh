#!/bin/bash
# Downloaded here: http://www.spinics.net/lists/linux-containers/msg24513.html
# Read the IP of an lxc run with 'lxc-start'
# Usage: $0 myvminlxc
#
# Convert hex to be uppercase for bc to accept it.
#
IN=`echo $1 | tr "[:lower:]" "[:upper:]" `
#
# Begin converting each octet
#

name=$1
[ -z "$name" ] && name=myvminlxc

cgroups=$(mount -l -t cgroup)
cgroup_path=""

for i in "$cgroups"; do
    cgroup_name=$(echo $i | awk ' { print $1 } ')
    cgroup_path=$(echo $i | awk ' { print $3 } ')

#    if [ "$cgroup_name" == "lxc" ]; then
#        break;
#    fi
done

if [ -z "$cgroup_path" ]; then
    echo "no cgroup mount point found"
    exit 1
fi

pid=$(head -1 $cgroup_path/$name/tasks)
if [ -z "$pid" ]; then
    pid=$(head -1 $cgroup_path/lxc/$name/tasks)
fi
if [ -z "$pid" ]; then
    echo "no process found for '$name'"
    exit 1
fi

IN=`cat /proc/$pid/net/rt_cache | sed -n "2p"| cut -f15`

IN1=`echo $IN| sed 's/^\(..\).*/ibase=16;\1/'|bc`
IN2=`echo $IN| sed 's/^..\(..\).*/ibase=16;\1/'|bc`
IN3=`echo $IN| sed 's/^....\(..\).*/ibase=16;\1/'|bc`
IN4=`echo $IN| sed 's/^......\(..\)/ibase=16;\1/'|bc`
#
# Begin gathering info on the resulting IP.
#
echo "$IN4.$IN3.$IN2.$IN1"
