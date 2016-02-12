# Setup Chef Server

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

# Create Cookbook

    chef generate cookbook cookbooks/$COOKBOOK

# Save Cookbook

    # Update `version` in cookbooks/$COOKBOOK/metadata.rb
    berks update -b cookbooks/$COOKBOOK/Berksfile
    berks upload -b cookbooks/$COOKBOOK/Berksfile

# Add Chef Supermarket Dependency

    # https://supermarket.chef.io/
    
    # Edit cookbooks/$COOKBOOK/Berksfile
    cookbook "$COOKBOOK"
    
    berks update -b cookbooks/$COOKBOOK/Berksfile
    berks upload -b cookbooks/$COOKBOOK/Berksfile

# Save Role

    knife role from file roles/db_server.json

# Save environment

    knife environment from file environments/production.json

# Create Server

    # Bare hostname (e.g. db1):
    NODE=X
    
    # Choose one:
    ROLE=[db_server|web_server]
    ENVIRONMENT=[production|test]
    
    # https://cloud.digitalocean.com/droplets/new
    # Region: San Francisco
    # Private Networking
    # Backups
    # IPV6
    # Hostname: $NODE.myplaceonline.com
    
    # https://cloud.digitalocean.com/networking
    # Create floating IP
    # ssh root@$NODE.myplaceonline.com "ifconfig eth1" | grep "inet "
    # https://cloud.digitalocean.com/domains/myplaceonline.com
    # Create DNS entry for $NAME with floating IP, and $NAME-internal with eth1 IP
    
    # Bootstrap with a blank recipe because `knife bootstrap` doesn't support
    # `--force-logger` so we wouldn't have good logging. Then run `knife ssh`
    # to set and run the "real" run_list.
    
    knife bootstrap ${NODE}.myplaceonline.com --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT}
    
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}],recipe[server_core]'" --ssh-user root --identity-file ~/.ssh/id_rsa

# Run cookbooks on node

    knife ssh "name:${NODE}" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa

# View Node JSON

    EDITOR=cat knife node edit $NODE

# Delete Node

    knife node delete $NODE
    knife client delete $NODE

# Find all nodes of a particular role and environment

    knife search "role:db_server AND chef_environment:production"
