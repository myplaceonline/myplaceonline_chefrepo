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

file "/etc/motd" do
  content myplaceonline_logo
end

execute "packages" do
  command "dnf -y install python multitail htop"
end

#package 'multitail'
