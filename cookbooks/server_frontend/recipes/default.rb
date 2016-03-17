template "/etc/yum.repos.d/SSLMate.repo" do
  source "SSLMate.repo"
end

package %w{sslmate}

template "/root/.sslmate" do
  source "sslmate.erb"
  mode "0600"
  variables :sslmate => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["sslmate"]
end

#execute "downloads ssl certs" do
#  user node.user.name
#  command "sslmate download www.#{node['system']['short_hostname']}.#{node['system']['domain_name']}"
#  returns [0,10]
#end
