#
# Cookbook Name:: hello_chef_server
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

file "#{Chef::Config[:file_cache_path]}/hello.txt" do
  content 'Hello, Chef server!'
end
