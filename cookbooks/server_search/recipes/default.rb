package %w{elastic-curator elasticdump elasticsearch}

template "/etc/elasticsearch/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  notifies :restart, "service[elasticsearch]", :immediately
end

service "elasticsearch" do
  action [:enable, :start]
end
