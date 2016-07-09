template "/etc/telegraf/telegraf.conf" do
  source "telegraf.conf.erb"
  notifies :restart, "service[telegraf]", :immediately
end

service "telegraf" do
  action [:enable, :start]
end

output_file = "/tmp/output"

package %w{gnupg ImageMagick ImageMagick-c++ ImageMagick-c++-devel ImageMagick-devel ImageMagick-libs golang git ruby rubygems ruby-devel redhat-rpm-config gcc gcc-c++ openssl-devel postgresql-devel postgresql nodejs libcurl-devel}

group "webgrp" do
  members "root"
end

directory "#{node.web.dir}" do
  mode "0750"
  group "webgrp"
  recursive true
end

git "#{node.web.dir}" do
  repository "https://github.com/myplaceonline/myplaceonline_rails"
  action :sync
end

template "/etc/nginx/conf.d/passenger.conf" do
  source "passenger.conf.erb"
end

file "#{node.web.dir}/log/passenger.log" do
  mode '0666'
end

template "/etc/nginx/nginx.conf" do
  source "nginx_core.conf.erb"
end

template "#{node.nginx.dir}/sites-available/#{node.app.name}.conf" do
  source "nginx.conf.erb"
  mode "0644"
  variables({
    :devise_secret => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["devise_secret"],
    :root_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["app"]["root_password"],
    :smtp_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["smtp_password"],
    :yelp => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["yelp"],
    :source_revision => %x{git --git-dir #{node.web.dir}/.git/ rev-parse HEAD}.strip
  })
end

directory "#{node.web.dir}" do
  mode '0755'
end

directory "#{node.web.dir}/tmp/" do
  mode "0777"
  recursive true
end

template "#{node.web.dir}/config/database.yml" do
  source "database.yml.erb"
  mode "0700"
  variables :postgres_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]
  owner "nobody" # database.yml is read within the context of Passenger, not nginx
end

directory "#{node.web.dir}/log/" do
  mode '0777'
end

file "#{node.web.dir}/log/production.log" do
  mode '0666'
end

execute "install bundler" do
  command "gem install bundler -q --no-rdoc --no-ri"
  not_if { `gem list bundler -i`.chomp == "true" }
end

execute "bundle install" do
  cwd "#{node.web.dir}/"
  command "bin/bundle install --deployment"
end

template "/root/.pgpass" do
  source "pgpass.erb"
  mode "0700"
  variables :postgres_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]
end

execute "initialize-setup" do
  cwd "#{node.web.dir}/"
  command "bin/bundle exec rake db:drop db:create db:schema:load db:seed"
  environment ({
    "RAILS_ENV" => node.chef_environment,
    "SECRET_KEY_BASE" => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["devise_secret"],
    "ROOT_EMAIL" => node.app.root_email,
    "ROOT_PASSWORD" => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["app"]["root_password"],
    "FTS_TARGET" => node.app.full_text_search_target
  })
  not_if { `psql -tA -U #{node.db.dbuser} -h #{node.db.host} -d #{node.db.dbname} -c \"\\dt\" | grep -c \"No relations found.\"`.chomp == "0" }
end

execute "migrate db" do
  cwd "#{node.web.dir}/"
  command "bin/bundle exec rake db:migrate &> #{output_file}"
  environment ({
    "RAILS_ENV" => node.chef_environment,
    "SECRET_KEY_BASE" => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["devise_secret"],
    "ROOT_EMAIL" => node.app.root_email,
    "ROOT_PASSWORD" => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["app"]["root_password"],
    "FTS_TARGET" => node.app.full_text_search_target
  })
end

ruby_block "migrate db results" do
  only_if { ::File.exists?(output_file) }
  block do
    print "\n"
    print File.read(output_file)
  end
end

execute "precompile assets" do
  cwd "#{node.web.dir}/"
  command "bin/bundle exec rake assets:precompile"
  environment ({"RAILS_ENV" => node.chef_environment})
end

nginx_site "#{node.app.name}.conf" do
  enable true
end

file "/root/.irbrc" do
  action :create_if_missing
  content "IRB.conf[:PROMPT_MODE] = :SIMPLE"
  mode "0700"
end

template "/var/spool/cron/root" do
  source "crontab.erb"
  mode "0600"
  variables ({
    :devise_secret => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["devise_secret"],
    :root_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["app"]["root_password"],
    :smtp_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["smtp_password"],
  })
end

service "nginx" do
  action "start"
end

execute "initialize with curl" do
  command "curl -s http://#{node.name}-internal.myplaceonline.com/ > /dev/null"
end
