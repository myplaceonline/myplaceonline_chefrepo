package %w{nginx}

execute "reload-systemd" do
  command "systemctl daemon-reload"
  action :nothing
end

template "/usr/lib/systemd/system/nginx.service" do
  source "nginx.service.erb"
  notifies :run, "execute[reload-systemd]", :immediately
end
