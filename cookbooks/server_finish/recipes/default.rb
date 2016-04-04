directory "#{node.nfs.client.mount}" do
  mode "0700"
end

ruby_block "nfs client" do
  block do
    file = Chef::Util::FileEdit.new("/etc/fstab")
    file.insert_line_if_no_match("/#{node.nfs.client.host}/", "#{node.nfs.client.host}:#{node.nfs.server.directory} #{node.nfs.client.mount} nfs timeo=5,intr")
    file.write_file
  end
end
