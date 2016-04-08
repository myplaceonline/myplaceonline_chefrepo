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
}

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

package %w{multitail strace htop mtr traceroute patch atop sysstat iotop gdb bind-utils ntp python sendmail make mailx postfix tcpdump cyrus-sasl-plain}

directory "/root/.ssh/" do
  mode "0700"
end

file "/root/.ssh/authorized_keys" do
  action :create_if_missing
  mode "0700"
end

swap_file '/swap1' do
  # size in MBs
  size data_bag_item("server", "server")["swap1"]
end

execute "update" do
  command "dnf -y update"
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
