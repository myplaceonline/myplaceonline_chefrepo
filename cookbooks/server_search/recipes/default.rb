# https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-repositories.html
file "/etc/yum.repos.d/elasticsearch.repo" do
  content %q{[elasticsearch-2.x]
name=Elasticsearch repository for 2.x packages
baseurl=https://packages.elastic.co/elasticsearch/2.x/centos
gpgcheck=0
gpgkey=https://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
}
end

package %w{elastic-curator elasticdump elasticsearch}

template "/etc/elasticsearch/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  notifies :restart, "service[elasticsearch]", :immediately
end

service "elasticsearch" do
  action [:enable, :start]
end

template "/etc/logstash/conf.d/logstash.conf" do
  source "logstash.conf.erb"
  notifies :restart, "service[logstash]", :immediately
end

service "logstash" do
  action [:enable, :start]
end

template "/etc/rsyslog.conf" do
  source "rsyslog.conf.erb"
  notifies :restart, "service[rsyslog]"
end

template "/etc/rsyslog.d/01-server.conf" do
  source "rsyslog_server.conf.erb"
  notifies :restart, "service[rsyslog]"
end

template "/etc/rsyslog.d/60-logstash.conf" do
  source "rsyslog_logstash.conf.erb"
  notifies :restart, "service[rsyslog]", :immediately
end

# https://www.elastic.co/guide/en/kibana/current/setup.html
file "/etc/yum.repos.d/kibana.repo" do
  content %q{[kibana-4.5]
name=Kibana repository for 4.5.x packages
baseurl=http://packages.elastic.co/kibana/4.5/centos
gpgcheck=0
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
}
end

package %w{kibana}
