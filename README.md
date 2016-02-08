The chef-repo
===============
All installations require a central workspace known as the chef-repo. This is a place where primitive objects--cookbooks, roles, environments, data bags, and chef-repo configuration files--are stored and managed.

The chef-repo should be kept under version control, such as [git](http://git-scm.org), and then managed as if it were source code.

Knife Configuration
-------------------
Knife is the [command line interface](https://docs.chef.io/knife.html) for Chef. The chef-repo contains a .chef directory (which is a hidden directory by default) in which the Knife configuration file (knife.rb) is located. This file contains configuration settings for the chef-repo.

The knife.rb file is automatically created by the starter kit. This file can be customized to support configuration settings used by [cloud provider options](https://docs.chef.io/plugin_knife.html) and custom [knife plugins](https://docs.chef.io/plugin_knife_custom.html).

Also located inside the .chef directory are .pem files, which contain private keys used to authenticate requests made to the Chef server. The USERNAME.pem file contains a private key unique to the user (and should never be shared with anyone). The ORGANIZATION-validator.pem file contains a private key that is global to the entire organization (and is used by all nodes and workstations that send requests to the Chef server).

More information about knife.rb configuration options can be found in [the documentation for knife](https://docs.chef.io/config_rb_knife.html).

Cookbooks
---------
A cookbook is the fundamental unit of configuration and policy distribution. A sample cookbook can be found in `cookbooks/starter`. After making changes to any cookbook, you must upload it to the Chef server using knife:

    $ knife upload cookbooks/starter

For more information about cookbooks, see the example files in the `starter` cookbook.

Roles
-----
Roles provide logical grouping of cookbooks and other roles. A sample role can be found at `roles/starter.rb`.

Getting Started
-------------------------
Now that you have the chef-repo ready to go, check out [Learn Chef](https://learn.chef.io/) to proceed with your workstation setup. If you have any questions about Chef you can always ask [our support team](https://www.chef.io/support/) for a helping hand.

Setup Chef Server
-----------------
    setenforce Permissive
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    yum install -y ntp python python3-yumdaemon sendmail make mailx cyrus-sasl-plain postfix letsencrypt
    systemctl start ntpd.service
    systemctl enable ntpd.service
    mkdir /etc/opscode/
    cat > /etc/opscode/chef-server.rb
      server_name = "admin.myplaceonline.com"
      api_fqdn server_name
      bookshelf['vip'] = server_name
      nginx['url'] = "https://#{server_name}"
      nginx['server_name'] = server_name
      nginx['ssl_certificate'] = "/var/opt/opscode/nginx/ca/#{server_name}.crt"
      nginx['ssl_certificate_key'] = "/var/opt/opscode/nginx/ca/#{server_name}.key"
    # Download chef server and scp to the box
    yum install -y chef-server-core-12.4.1-1.el7.x86_64.rpm && rm -f chef-server-core-12.4.1-1.el7.x86_64.rpm
    chef-server-ctl reconfigure
    vi /opt/opscode/embedded/cookbooks/private-chef/recipes/add_ons_repository.rb
      when 'rhel', 'fedora'

        major_version = node['platform_version'].split('.').first
        if node['platform_family'] == "fedora"
          major_version = "7"
        end
    vi /opt/opscode/embedded/cookbooks/private-chef/recipes/add_ons_remote.rb
      when 'rhel', 'fedora'
    chef-server-ctl install opscode-manage
    chef-server-ctl reconfigure
    opscode-manage-ctl reconfigure
    chef-server-ctl install opscode-reporting
    chef-server-ctl reconfigure
    opscode-reporting-ctl reconfigure
    vi /etc/postfix/sasl_passwd
      [smtp.mandrillapp.com] root@myplaceonline.com:API_KEY
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    vi /etc/postfix/main.cf
      smtp_sasl_auth_enable = yes
      smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd 
      smtp_sasl_security_options = noanonymous
      smtp_use_tls = yes
      relayhost = [smtp.mandrillapp.com]
    systemctl start postfix.service
    systemctl enable postfix.service
    sendmail RECIPIENT@domain.com
      From: you@yourdomain.com
      Subject: Testing from Postfix
      This is a test email
      .
    chef-server-ctl user-create root root root root@myplaceonline.com ADMIN_PASSWORD --filename root.pem
    chef-server-ctl org-create myplaceonline "myplaceonline" --association_user root
    chef-server-ctl stop nginx
    letsencrypt certonly
    vi /etc/opscode/chef-server.rb
      nginx['ssl_certificate'] = "/etc/letsencrypt/live/admin.myplaceonline.com/fullchain.pem"
      nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/admin.myplaceonline.com/privkey.pem"
    chef-server-ctl reconfigure

Commands
--------

    chef generate cookbook cookbooks/hello_chef_server
    knife cookbook upload hello_chef_server
    knife cookbook list
    knife bootstrap db.myplaceonline.com --ssh-user root --sudo --identity-file ~/.ssh/id_rsa --node-name db --run-list 'recipe[server_core]'
    
    knife cookbook upload server_core
    ssh root@db.myplaceonline.com chef-client