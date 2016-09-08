# Ruby uses a lot of memory, so things like dnf updates can run OOM, so
# we first stop ruby
begin
  Chef::Log.info "Stopping nginx"
  service "nginx" do
    action "stop"
  end
  Chef::Log.info "nginx stopped"

  # rsyslog has a tendency to build up a few hundred MB of memory
  # which can push us over the edge when running the update,
  # so restart it
  service "rsyslog" do
    action "restart"
  end
  Chef::Log.info "Restarted rsyslog"

rescue Exception
  # If this is the first execution, there won't be an nginx service
  Chef::Log.info "Exception stopping nginx"
end
