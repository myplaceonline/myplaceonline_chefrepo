template "/etc/yum.repos.d/SSLMate.repo" do
  source "SSLMate.repo"
end

package %w{sslmate haproxy}

template "/root/.sslmate" do
  source "sslmate.erb"
  mode "0600"
  variables :sslmate => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["sslmate"]
end

directory "/etc/sslmate/" do
  mode "0755"
end

file "/etc/sslmate/www.myplaceonline.com.key" do
  action :create_if_missing
  content data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["keys"]["sslmate"]["private"]
  mode "0700"
end

execute "downloads ssl certs" do
  command "sslmate download #{node.sslmate.certname}"
  returns [0,10]
end

template "/etc/haproxy/haproxy.cfg" do
  source "haproxy.cfg.erb"
  mode "0644"
  variables({
    :web_servers => search(:node, "chef_environment:#{node.chef_environment} AND role:web_server")
  })
  notifies :restart, "service[haproxy]"
end

service "haproxy" do
  action [:enable, :start]
end
