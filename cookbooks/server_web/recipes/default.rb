package %w{gnupg ImageMagick ImageMagick-c++ ImageMagick-c++-devel ImageMagick-devel ImageMagick-libs golang git}

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
