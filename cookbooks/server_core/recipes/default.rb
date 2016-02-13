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
  hostname: #{node["hostname"]}
  machinename: #{node["machinename"]}
  fqdn: #{node["fqdn"]}
  domain: #{node["domain"]}
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

template "/etc/commonprofile.sh" do
  source "commonprofile.sh"
  mode "0755"
end

ruby_block "add login profile script" do
  block do
    fe = Chef::Util::FileEdit.new("/etc/profile")
    fe.insert_line_if_no_match(/commonprofile/, "source /etc/commonprofile.sh")
    fe.write_file
  end
end

file "/etc/motd" do
  content myplaceonline_logo
end

ruby_block "update sysctl" do
  block do
    fe = Chef::Util::FileEdit.new("/etc/sysctl.conf")
    fe.insert_line_if_no_match(/swappiness/, "vm.swappiness=0")
    fe.write_file
  end
end

execute "commands" do
  command %{
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime;
    dnf -y install python python-dnf multitail htop;
    sysctl -p;
  }
end

template "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" do
  source "dnf-query.py"
  mode "0755"
end

package %w{multitail strace htop}

directory "/root/.ssh/" do
  mode "0700"
end

file "/root/.ssh/authorized_keys" do
  mode "0700"
end

swap_file '/swap1' do
  # size in MBs
  size data_bag_item("server_core", "server")["swap1"]
end
