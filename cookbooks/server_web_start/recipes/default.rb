# Ruby uses a lot of memory, so things like dnf updates can run OOM, so
# we first stop ruby
begin
  Chef::Log.info "Stopping nginx"
  service "nginx" do
    action "stop"
  end
  Chef::Log.info "nginx stopped"
rescue Exception
  # If this is the first execution, there won't be an nginx service
  Chef::Log.info "Exception stopping nginx"
end
