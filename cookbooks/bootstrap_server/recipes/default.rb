#
# Cookbook Name:: bootstrap_server
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

directory "#{data_bag_item("server", "server")["secrets_dir"]}" do
  mode "0700"
end

# Could've used shutdown with +1 but it was broken at time of writing
# (https://github.com/systemd/systemd/issues/1120)
execute "commands" do
  command %{
    dnf -y install at;
    dnf -y update;
    echo "reboot" | at now + 1 minutes;
  }
end
