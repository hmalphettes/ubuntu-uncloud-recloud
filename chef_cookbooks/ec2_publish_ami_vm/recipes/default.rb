#
# Cookbook Name:: intalio_cf
# Recipe:: default
#
# Copyright 2012, Intalio Pte
#

# enable multiverse
bash "enable multiverse" do
  code <<EOF
still=`egrep "^# deb .*multiverse" /etc/apt/sources.list`
echo "$still"
if [ -n "$still" ]; then
  sed -i "s/^# deb \\(.*\\) multiverse/deb \\1 multiverse/" /etc/apt/sources.list
  sed -i "s/^# deb-src \\(.*\\) multiverse/deb \\1 multiverse/" /etc/apt/sources.list
  still=`egrep "^# deb .*multiverse" /etc/apt/sources.list`
  [ -n "$still" ] && echo "Failed to enable multiverse" && exit 2
  apt-get update
fi
EOF
end

#
%w{curl wget unzip git-core
   e2fsprogs
   ec2-api-tools
   qemu-kvm virtualbox-ose
  }.each do |p|
  package p do
    action [:install]
  end

end
# the parameters
template "build_params.erb" do
  path "/home/#{node[:deployment][:user]}/build_params.sh"
  source "build_params.sh.erb"
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode 0644
end

git node[:recloud][:script][:installation_folder] do
  repository node[:recloud][:script][:repo]
  revision node[:recloud][:script][:branch]
  depth 1
  action :sync
  user node[:deployment][:user]
  group node[:deployment][:group]
end

