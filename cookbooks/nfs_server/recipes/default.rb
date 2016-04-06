package %w{nfs-utils}

directory "#{node.nfs.server.directory}" do
  mode "0700"
end

service "rpcbind" do
  action [:enable, :start]
end

template "/etc/exports" do
  source "exports.erb"
  notifies :restart, "service[nfs-server]", :immediately
end

service "nfs-server" do
  action [:enable, :start]
end
