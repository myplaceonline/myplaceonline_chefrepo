template "/etc/telegraf/telegraf.conf" do
  source "telegraf.conf.erb"
  notifies :restart, "service[telegraf]", :immediately
end

service "telegraf" do
  action [:enable, :start]
end

package %w{haproxy socat nmap-ncat}

# Strange dependency error on Fedora, need to retry later
#package %w{letsencrypt}

directory "/etc/haproxy/ssl/" do
  mode "0700"
  owner "haproxy"
  group "haproxy"
end

execute "initial-cert" do
  command "/usr/bin/letsencrypt --agree-tos --renew-by-default --email contact@myplaceonline.com --standalone --standalone-supported-challenges http-01 --http-01-port 9999 certonly -d myplaceonline.com -d www.myplaceonline.com && cat /etc/letsencrypt/live/myplaceonline.com/{fullchain.pem,privkey.pem} > /etc/haproxy/ssl/myplaceonline.com.pem"
  only_if { !Dir.exists?("/etc/letsencrypt/live/") }
end

template "/etc/cron.d/letsencrypt" do
  source "crontab_letsencrypt"
  mode "0600"
end

template "/etc/rsyslog.d/haproxy.conf" do
  source "rsyslog_haproxy.conf.erb"
  notifies :restart, "service[rsyslog]", :immediately
end

template "/etc/haproxy/haproxy.cfg" do
  source "haproxy.cfg.erb"
  mode "0644"
  variables({
    :web_servers => search(:node, "chef_environment:#{node.chef_environment} AND role:web_server"),
    :stats_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["haproxy"]["stats"]
  })
  notifies :reload, "service[haproxy]", :immediately
end

service "haproxy" do
  action [:enable, :start]
end
