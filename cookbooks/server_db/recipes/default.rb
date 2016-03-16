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

execute "create-postgres-myplaceonline-user" do
  command "sudo -i -u postgres psql -c \"CREATE ROLE myplaceonline WITH LOGIN ENCRYPTED PASSWORD '#{data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]}' CREATEDB;\""
  not_if { `sudo -i -u postgres psql -tAc \"SELECT * FROM pg_roles WHERE rolname='myplaceonline'\" | wc -l`.chomp == "1" }
end
