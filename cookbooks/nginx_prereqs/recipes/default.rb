package %w{nginx ruby rubygems ruby-devel redhat-rpm-config}

execute "reload-systemd" do
  command "systemctl daemon-reload"
  action :nothing
end

template "/usr/lib/systemd/system/nginx.service" do
  source "nginx.service.erb"
  notifies :run, "execute[reload-systemd]", :immediately
end

execute "symlink" do
  command %{
    mkdir #{node.nginx.passenger.root}ext;
    ln -s #{node.nginx.passenger.root}src/nginx_module #{node.nginx.passenger.root}ext/nginx
  }
  action :nothing
  subscribes :run, "gem_package[passenger]", :immediate
end
