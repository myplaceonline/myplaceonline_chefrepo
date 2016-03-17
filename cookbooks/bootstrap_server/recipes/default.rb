# There is no point to call Chef::Log because it won't go to the knife
# bootstrap output (see parent README for details)

directory "#{data_bag_item("server", "server")["secrets_dir"]}" do
  mode "0700"
end

execute "commands1" do
  command "setenforce Permissive"
end

execute "commands2" do
  command "dnf -y install at"
end

execute "commands4" do
  command "systemctl enable atd.service"
end

execute "commands5" do
  command "systemctl start atd.service"
end

execute "commands6" do
  command "dnf -y update"
  returns [0,1] # Cannot reproduce return code 1 when run manually, but it seems okay
end

# Could've used shutdown with +1 but it was broken at time of writing
# (https://github.com/systemd/systemd/issues/1120)
execute "commands7" do
  command "echo \"reboot\" | at now + 1 minutes"
end

execute "commands8" do
  command "echo \"Please wait 2 minutes while the server reboots...\""
end
