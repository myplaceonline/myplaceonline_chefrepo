# There is no point to call Chef::Log because it won't go to the knife
# bootstrap output (see parent README for details)

directory "#{data_bag_item("server", "server")["secrets_dir"]}" do
  mode "0700"
end

# Could've used shutdown with +1 but it was broken at time of writing
# (https://github.com/systemd/systemd/issues/1120)
execute "commands" do
  command %{
    setenforce Permissive && \
    dnf -y install at && \
    dnf -y --setopt=deltarpm=false update && \
    echo "reboot" | at now + 1 minutes && \
    echo "Please wait 2 minutes while the server reboots..."
  }
end
