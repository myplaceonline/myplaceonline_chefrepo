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

directory "#{data_bag_item("server", "server")["secrets_dir"]}" do
  mode "0700"
end

Chef::Log.info %{#{myplaceonline_logo}
  Updating all packages and rebooting...
}

# Could've used shutdown with +1 but it was broken at time of writing
# (https://github.com/systemd/systemd/issues/1120)
execute "commands" do
  command %{
    dnf -y install at && \
    dnf -y update && \
    echo "reboot" | at now + 1 minutes && \
    echo "Please wait 2 minutes while the server reboots..."
  }
end
