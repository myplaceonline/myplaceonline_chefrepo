# https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-repositories.html
file "/etc/yum.repos.d/elasticsearch.repo" do
  content %q{[elasticsearch-5.x]
name=Elasticsearch repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
}
end

package %w{elastic-curator elasticdump elasticsearch}

template "/etc/elasticsearch/jvm.options" do
  source "elasticsearch_jvm.options.yml"
  notifies :restart, "service[elasticsearch]", :immediately
end

template "/etc/elasticsearch/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  notifies :restart, "service[elasticsearch]", :immediately
end

service "elasticsearch" do
  action [:enable, :start]
end

template "/etc/logstash/jvm.options" do
  source "logstash_jvm.options.erb"
  notifies :restart, "service[logstash]", :immediately
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
  content %q{[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
}
end

package %w{kibana}
