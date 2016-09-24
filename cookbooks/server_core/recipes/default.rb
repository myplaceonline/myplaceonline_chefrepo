myplaceonline_logo = %q{
                        _                            _ _            
                       | |                          | (_)           
  _ __ ___  _   _ _ __ | | __ _  ___ ___  ___  _ __ | |_ _ __   ___ 
 | '_ ` _ \| | | | '_ \| |/ _` |/ __/ _ \/ _ \| '_ \| | | '_ \ / _ \
 | | | | | | |_| | |_) | | (_| | (_|  __/ (_) | | | | | | | | |  __/
 |_| |_| |_|\__, | .__/|_|\__,_|\___\___|\___/|_| |_|_|_|_| |_|\___|
             __/ | |                                                
            |___/|_|                                                
} + "\n\n"

ENV["TZ"] = "UTC"

Chef::Log.info %{#{myplaceonline_logo}
  OS: #{node["kernel"]["name"]} #{node["kernel"]["release"]}
      #{node["os"]} #{node["platform"]} #{node["platform_version"]}
      #{node["uptime"]}
  name: #{node.name}
  hostname: #{node.hostname}
  machinename: #{node.machinename}
  fqdn: #{node.fqdn}
  domain: #{node.domain}
  roles: #{node["roles"].inspect}
  environment: #{node.chef_environment}
  memory (MB): #{node["memory"]["total"].to_f/1024}
}

# Machines may be memory constrained, so disable crons for the duration
# of the chef-client run. Re-enable in the server_finish cookbook
service "crond" do
  action [:stop]
  only_if { Dir.exists?("/etc/cron.d") }
end

execute "info" do
  command %{
    echo "";
    df -h | grep -v tmpfs;
    echo "";
    free -m;
    echo "";
    cat /proc/cpuinfo | grep -e processor -e MHz
    echo "";
  }
end

selinux_state "selinux-permissive" do
  action :permissive
end

execute "runtime-selinux-permissive" do
  command "setenforce Permissive"
  only_if { `getenforce`.chomp != "Permissive" }
end

file "/root/.passwd" do
  content data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["root"]
end

# We set a root password in the case we need to do a manual login from the web console
execute "set-root-password" do
  command %{
    passwd --stdin root < /root/.passwd;
    rm -f /root/.passwd;
  }
end

template "/etc/commonprofile.sh" do
  source "commonprofile.sh"
  mode "0755"
end

template "/etc/profile" do
  source "profile"
end

file "/etc/motd" do
  content myplaceonline_logo
end

execute "reload-sysctl" do
  command "sysctl -p"
  action :nothing
end

template "/etc/sysctl.conf" do
  source "sysctl.conf"
  notifies :run, 'execute[reload-sysctl]', :immediately
end

execute "restart-journald" do
  command "systemctl restart systemd-journald"
  action :nothing
end

template "/etc/systemd/journald.conf" do
  source "journald.conf.erb"
  notifies :run, 'execute[restart-journald]', :immediately
end

execute "commands1" do
  command %{
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime;
    dnf -y install python python-dnf multitail htop lsof wget;
    dnf -y --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install kernel-debuginfo-common-x86_64 kernel-debuginfo glibc-debuginfo-common glibc-debuginfo systemtap perf;
  }
end

template "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" do
  source "dnf-query.py"
  mode "0755"
end

file "/etc/yum.repos.d/influxdb.repo" do
  content %q{[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
enabled = 1
gpgcheck = 0
gpgkey = https://repos.influxdata.com/influxdb.key
} 
end

package %w{multitail strace htop mtr traceroute patch atop sysstat iotop gdb bind-utils ntp python sendmail make mailx postfix tcpdump cyrus-sasl-plain rsyslog gnupg kexec-tools lzo lzo-devel lzo-minilzo bison bison-devel ncurses ncurses-devel telegraf telnet iftop git}

service "atop" do
  action [:enable, :start]
end

template "/etc/rsyslog.conf" do
  source "rsyslog.conf.erb"
  notifies :restart, "service[rsyslog]", :delayed # some servers have a different syslog config, so don't update syslog immediately
end

service "rsyslog" do
  action [:enable, :start]
end

template "/etc/kdump.conf" do
  source "kdump.conf.erb"
end

service "kdump" do
  action [:enable] # don't auto-start because we may not have crashkernel yet
end

execute "update-grub" do
  command "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg"
  action :nothing
end

template "/etc/default/grub" do
  source "grub.erb"
  notifies :run, "execute[update-grub]", :immediately
end

directory "/root/.ssh/" do
  mode "0700"
end

file "/root/.ssh/authorized_keys" do
  action :create_if_missing
  mode "0700"
end

#swap_file '/swap1' do
  # size in MBs
#  size data_bag_item("server", "server")["swap1"]
#end

execute "update" do
  command %{
    dnf -y update;
    dnf -y --enablerepo fedora-debuginfo --enablerepo updates-debuginfo update;
  }
end

service "ntpd" do
  action [:enable, :start]
end

template "/etc/postfix/main.cf" do
  source "main.cf.erb"
  variables ({
    :smtp_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["smtp_password"]
  })
end

service "postfix" do
  action [:enable, :start]
end

template "/etc/security/limits.conf" do
  source "limits.conf.erb"
end

template "/root/.toprc" do
  source "toprc" # Run `top` on a server, customize as needed, type `W` and then use that file (no support for erb)
end

execute "install crash" do
  command %{
    cd /usr/local/src/;
    rm -rf crash*;
    git clone https://github.com/crash-utility/crash/;
    cd crash;
    echo '-DLZO' > CFLAGS.extra;
    echo '-llzo2' > LDFLAGS.extra;
    make;
  }
  not_if { File.exist?("/usr/local/src/crash/crash") }
end

# https://www.elastic.co/guide/en/logstash/current/installing-logstash.html
file "/etc/yum.repos.d/influxdb.repo" do
  content %q{[logstash-2.3]
name=Logstash repository for 2.3.x packages
baseurl=http://packages.elastic.co/logstash/2.3/centos
gpgcheck=0
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
}
end

package %w{logstash java-1.8.0-openjdk}

if node["roles"].index("db_server_backup").nil?
  template "/opt/logstash/bin/logstash" do
    source "logstash.erb"
  #  notifies :restart, "service[logstash]", :immediately
  end

  #service "logstash" do
  #  action [:enable, :start]
  #end
  
  template "/etc/rsyslog.d/01-client.conf" do
    source "rsyslog_client.conf.erb"
    notifies :restart, "service[rsyslog]", :immediately
  end
end
