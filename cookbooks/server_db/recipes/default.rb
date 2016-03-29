# https://fedoraproject.org/wiki/PostgreSQL

# repmgr can't be built until Fedora 24 due to https://bugzilla.redhat.com/show_bug.cgi?id=784281
# so we use PGDG

if !File.exist?("/etc/yum.repos.d/pgdg-95-fedora.repo")
  execute "postgres repo" do
    command "dnf install -y https://download.postgresql.org/pub/repos/yum/9.5/fedora/fedora-23-x86_64/pgdg-fedora95-9.5-3.noarch.rpm"
  end
end

execute "postgres install" do
  command "dnf install -y --nogpgcheck postgresql95-server postgresql95-contrib postgresql95-devel redhat-rpm-config readline-devel openssl-devel libxslt-devel pam-devel"
end

execute "postgre init" do
  command "/usr/pgsql-#{node.postgresql.version}/bin/postgresql95-setup initdb"
  only_if { `ls -l /var/lib/pgsql/#{node.postgresql.version}/data/ | wc -l`.chomp == "1" }
end

service "postgresql-#{node.postgresql.version}" do
  action [:enable, :start]
end

#web_servers = search(:node, "role:web_server")

template "/var/lib/pgsql/#{node.postgresql.version}/data/pg_hba.conf" do
  source "pg_hba.conf.erb"
  notifies :restart, "service[postgresql-#{node.postgresql.version}]"
  #variables :web_servers => web_servers
end

template "/var/lib/pgsql/#{node.postgresql.version}/data/postgresql.conf" do
  source "postgresql.conf.erb"
  notifies :restart, "service[postgresql-#{node.postgresql.version}]"
end

log "check master" do
  message %{
    postgresql master = #{node.postgresql.master}
  }
  level :info
end

if node.postgresql.master
  execute "create-postgres-myplaceonline-user" do
    command "sudo -i -u postgres psql -c \"CREATE ROLE #{node.db.dbuser} WITH LOGIN ENCRYPTED PASSWORD '#{data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]}' SUPERUSER;\""
    not_if { `sudo -i -u postgres psql -tAc \"SELECT * FROM pg_roles WHERE rolname='#{node.db.dbuser}'\" | wc -l`.chomp == "1" }
  end

  execute "create-postgres-myplaceonline-db" do
    command "sudo -i -u postgres psql -c \"CREATE DATABASE #{node.db.dbname} WITH OWNER #{node.db.dbuser};\""
    not_if { `sudo -i -u postgres psql -tAc \"SELECT datname FROM pg_database WHERE datname = '#{node.db.dbname}' and datistemplate = false;\" | wc -l`.chomp == "1" }
  end
end

directory "/var/lib/pgsql/.ssh/" do
  mode "0700"
  owner "postgres"
  group "postgres"
end

file "/var/lib/pgsql/.ssh/authorized_keys" do
  action :create_if_missing
  content node["keys"]["postgresql"]["public"]
  mode "0700"
  owner "postgres"
  group "postgres"
end

file "/var/lib/pgsql/.ssh/id_rsa" do
  action :create_if_missing
  content data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["keys"]["postgresql"]["private"]
  mode "0700"
  owner "postgres"
  group "postgres"
end

search(:node, "chef_environment:#{node.chef_environment} AND role:db_server*").each do |dbserver|
  if dbserver.name != node.name
    target = dbserver["fqdn"]
    target = target.insert(target.index('.'), "-internal")
    
    log "server info" do
      message %{
        Processing #{dbserver["fqdn"]}
      }
      level :info
    end
    
    execute "trust host" do
      command %{
        touch /var/lib/pgsql/.ssh/known_hosts;
        ssh-keyscan -t rsa,dsa #{target} 2>&1 | sort -u - /var/lib/pgsql/.ssh/known_hosts > /var/lib/pgsql/.ssh/tmp_hosts;
        mv /var/lib/pgsql/.ssh/tmp_hosts /var/lib/pgsql/.ssh/known_hosts;
      }
      user "postgres"
    end
  end
end

if !File.exist?("/usr/pgsql-#{node.postgresql.version}/bin/repmgr")
  execute "install repmgr" do
    command %{
      cd /usr/local/src/;
      wget https://github.com/2ndQuadrant/repmgr/archive/v3.1.1.tar.gz;
      tar xzvf v3.1.1.tar.gz;
      cd repmgr-3.1.1;
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/usr/pgsql-#{node.postgresql.version}/bin/;
      make USE_PGXS=1 install;
    }
  end
end
