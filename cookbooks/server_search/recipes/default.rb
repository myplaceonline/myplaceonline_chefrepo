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

package %w{elastic-curator elasticdump elasticsearch logstash}

template "/etc/elasticsearch/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  notifies :restart, "service[elasticsearch]", :immediately
end

service "elasticsearch" do
  action [:enable, :start]
end
