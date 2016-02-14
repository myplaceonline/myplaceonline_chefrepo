#
# Cookbook Name:: server_db
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# https://fedoraproject.org/wiki/PostgreSQL
package %w{postgresql-server postgresql-contrib}

execute "postgre init" do
  command "postgresql-setup --initdb --unit postgresql"
  only_if { `ls -l /var/lib/pgsql/data/ | wc -l`.chomp == "1" }
end

service "postgresql" do
  action [:enable, :start]
end

template "/var/lib/pgsql/data/pg_hba.conf" do
  source "pg_hba.conf.erb"
  notifies :restart, "service[postgresql]"
end

template "/var/lib/pgsql/data/postgresql.conf" do
  source "postgresql.conf.erb"
  notifies :restart, "service[postgresql]"
end
