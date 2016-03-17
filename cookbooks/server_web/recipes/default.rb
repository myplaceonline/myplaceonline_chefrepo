package %w{gnupg ImageMagick ImageMagick-c++ ImageMagick-c++-devel ImageMagick-devel ImageMagick-libs golang git ruby rubygems ruby-devel redhat-rpm-config gcc gcc-c++ openssl-devel postgresql-devel}

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

template "#{node.web.dir}/config/database.yml" do
  source "database.yml.erb"
  mode "0750"
  variables :postgres_password => data_bag_item("globalsecrets", "globalsecrets", IO.read(data_bag_item("server", "server")["secrets_dir"] + "secret_key_databag_globalsecrets"))["passwords"]["postgresql"]["myplaceonline"]
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
