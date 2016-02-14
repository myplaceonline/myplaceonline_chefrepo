#
# Cookbook Name:: bootstrap_server
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

directory "#{data_bag_item("server", "server")["secrets_dir"]}" do
  mode "0700"
end
