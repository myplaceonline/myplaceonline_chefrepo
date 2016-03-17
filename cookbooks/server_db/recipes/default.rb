# https://fedoraproject.org/wiki/PostgreSQL
package %w{postgresql-server postgresql-contrib}

execute "postgre init" do
  command "postgresql-setup --initdb --unit postgresql"
  only_if { `ls -l /var/lib/pgsql/data/ | wc -l`.chomp == "1" }
end

service "postgresql" do
  action [:enable, :start]
end

#web_servers = search(:node, "role:web_server")

template "/var/lib/pgsql/data/pg_hba.conf" do
  source "pg_hba.conf.erb"
  notifies :restart, "service[postgresql]"
  #variables :web_servers => web_servers
end

template "/var/lib/pgsql/data/postgresql.conf" do
  source "postgresql.conf.erb"
  notifies :restart, "service[postgresql]"
end

execute "create-postgres-myplaceonline-user" do
  command "sudo -i -u postgres psql -c \"CREATE ROLE #{node.db.dbuser} WITH LOGIN ENCRYPTED PASSWORD '#{data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]}' SUPERUSER;\""
  not_if { `sudo -i -u postgres psql -tAc \"SELECT * FROM pg_roles WHERE rolname='#{node.db.dbuser}'\" | wc -l`.chomp == "1" }
end

execute "create-postgres-myplaceonline-db" do
  command "sudo -i -u postgres psql -c \"CREATE DATABASE #{node.db.dbname} WITH OWNER #{node.db.dbuser};\""
  not_if { `sudo -i -u postgres psql -tAc \"SELECT datname FROM pg_database WHERE datname = '#{node.db.dbname}' and datistemplate = false;\" | wc -l`.chomp == "1" }
end
