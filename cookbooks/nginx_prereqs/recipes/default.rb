package %w{nginx ruby rubygems ruby-devel}

execute "reload-systemd" do
  command "systemctl daemon-reload"
  action :nothing
end

template "/usr/lib/systemd/system/nginx.service" do
  source "nginx.service.erb"
  notifies :run, "execute[reload-systemd]", :immediately
end

directory "#{node.nginx.passenger.root}ext/" do
  mode '0755'
  recursive true
end

execute "symlink" do
  command "ln -s #{node.nginx.passenger.root}src/nginx_module #{node.nginx.passenger.root}ext/nginx"
end
