package %w{nfs-utils}

directory "#{node.nfs.client.mount}" do
  mode "0777"
end

ruby_block "nfs client" do
  block do
    file = Chef::Util::FileEdit.new("/etc/fstab")
    file.insert_line_if_no_match(/#{Regexp.escape(node.nfs.client.host)}/, "#{node.nfs.client.host}:#{node.nfs.server.directory} #{node.nfs.client.mount} nfs timeo=5,intr")
    file.write_file
  end
end

execute "mount nfs" do
  command "mount -a"
  only_if { `df -h #{node.nfs.client.mount} | grep #{node.nfs.client.host} | wc -l`.chomp == "0" }
end

directory "#{node.nfs.client.mount}" do
  mode "0777"
end
