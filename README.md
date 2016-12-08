# Setup Chef Server

    setenforce Permissive
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    yum install -y ntp python python3-yumdaemon sendmail make mailx cyrus-sasl-plain postfix letsencrypt wget
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
    vi /etc/postfix/main.cf
      smtp_sasl_auth_enable = yes 
      smtp_sasl_password_maps = static:myplaceonline:$PASSWORD
      smtp_sasl_security_options = noanonymous
      smtp_tls_security_level = encrypt
      header_size_limit = 4096000
      relayhost = [smtp.sendgrid.net]:587
    systemctl start postfix.service
    systemctl enable postfix.service
    echo "This is the message body" | mail -s "This is the subject" -r root@myplaceonline.com kevgrig@gmail.com
    chef-server-ctl user-create root root root root@myplaceonline.com ADMIN_PASSWORD --filename root.pem
    chef-server-ctl org-create myplaceonline "myplaceonline" --association_user root
    chef-server-ctl stop nginx
    letsencrypt certonly
    # Also update grafana certs below (same certs, just copy and restart)
    vi /etc/opscode/chef-server.rb
      nginx['ssl_certificate'] = "/etc/letsencrypt/live/admin.myplaceonline.com/fullchain.pem"
      nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/admin.myplaceonline.com/privkey.pem"
    chef-server-ctl reconfigure
    
    vi /etc/sysctl.conf
      vm.swappiness=0
      net.core.rmem_default=1048576
      net.core.wmem_default=1048576
      net.core.rmem_max=16777216
      net.core.wmem_max=16777216
      net.ipv4.tcp_rmem=4096 1048576 16777216
      net.ipv4.tcp_wmem=4096 1048576 16777216

    dnf install firewalld
    systemctl start firewalld.service
    systemctl enable firewalld.service
    firewall-cmd --add-service=https

    cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
    [influxdb]
    name = InfluxDB Repository - RHEL \$releasever
    baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
    enabled = 1
    gpgcheck = 1
    gpgkey = https://repos.influxdata.com/influxdb.key
    EOF

    dnf install influxdb
    vi /etc/influxdb/influxdb.conf
      Replace all binds with internal IP
      And add to the top
        bind-address = "10.134.6.221:8088"
    vi /usr/lib/systemd/system/influxdb.service
      network-online
    systemctl daemon-reload
    systemctl enable influxdb
    systemctl start influxdb
    influx -host admin-internal.myplaceonline.com
      CREATE DATABASE telegraf
      CREATE USER influxadmin WITH PASSWORD '$PASSWORD' WITH ALL PRIVILEGES
      
    cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
    [grafana]
    name=grafana
    baseurl=https://packagecloud.io/grafana/stable/el/6/
    repo_gpgcheck=1
    enabled=1
    gpgcheck=1
    gpgkey=https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
    sslverify=1
    sslcacert=/etc/pki/tls/certs/ca-bundle.crt
    EOF

      dnf install grafana
    dnf install fontconfig freetype* urw-fonts
    cp /etc/letsencrypt/live/admin.myplaceonline.com/cert.pem /etc/letsencrypt/live/admin.myplaceonline.com/privkey.pem /etc/grafana/
    chown grafana:grafana /etc/grafana/*pem
    chmod go-r /etc/grafana/*pem
    vi /etc/grafana/grafana.ini
      Update admin password in 
      protocol = https
      domain = admin.myplaceonline.com
      cert_file = /etc/grafana/cert.pem
      cert_key = /etc/grafana/privkey.pem
    systemctl start grafana-server
    systemctl enable grafana-server.service
    firewall-cmd --zone=public --add-port=3000/tcp --permanent
    firewall-cmd --zone=public --add-port=443/tcp --permanent
    firewall-cmd --reload
    vi /etc/sysconfig/network-scripts/ifcfg-eth1
      ZONE=trusted
    reboot
    http://docs.grafana.org/datasources/influxdb/
      http://admin-internal.myplaceonline.com:8086/
      mydb
      influxadmin
    
    influx -host admin-internal.myplaceonline.com -database telegraf
      show measurements
      show tag keys
      show field keys
      show retention policies on telegraf
      show series
      
    curl -G 'http://admin-internal.myplaceonline.com:8086/query?db=telegraf' --data-urlencode 'q=SHOW TAG VALUES FROM cpu WITH KEY = host'

## Update Certificates

    chef-server-ctl stop nginx
    letsencrypt certonly
    chef-server-ctl start nginx
    cp /etc/letsencrypt/live/admin.myplaceonline.com/cert.pem /etc/letsencrypt/live/admin.myplaceonline.com/privkey.pem /etc/grafana/
    chown grafana:grafana /etc/grafana/*pem
    chmod go-r /etc/grafana/*pem
    systemctl restart grafana-server

# Create Cookbook

    COOKBOOK=...
    chef generate cookbook cookbooks/$COOKBOOK
    berks install -b cookbooks/$COOKBOOK/Berksfile

# Save Cookbook

    # Update `version` in cookbooks/$COOKBOOK/metadata.rb
    COOKBOOK=server_core; berks install -b cookbooks/$COOKBOOK/Berksfile && berks update -b cookbooks/$COOKBOOK/Berksfile && berks upload -b cookbooks/$COOKBOOK/Berksfile

# Add Chef Supermarket Dependency

    # https://supermarket.chef.io/
    
    # Edit cookbooks/$COOKBOOK/Berksfile
    cookbook "$COOKBOOK"
    
    berks update -b cookbooks/$COOKBOOK/Berksfile && berks upload -b cookbooks/$COOKBOOK/Berksfile

# Save Role

    knife role from file roles/db_server.json

# Save environment

    knife environment from file environments/production.json

# Show environment

    knife environment show production

# Create Server

    # https://cloud.digitalocean.com/droplets/new
    # Region: San Francisco
    # Private Networking
    # IPV6
    # Select SSH Key
    # Hostname: $NODE.myplaceonline.com
    
    # Bare hostname (e.g. db1):
    NODE=X
    
    # Choose one:
    ROLE=[db_server|web_server]
    ENVIRONMENT=[production|test]
    
    # https://cloud.digitalocean.com/networking
    # Create floating IP
    # Create DNS A entry for $NAME with floating IP
    # ssh root@$NODE.myplaceonline.com "ifconfig eth1" | grep "inet "
    # https://cloud.digitalocean.com/domains/myplaceonline.com
    # Create DNS A entry for $NAME-internal with eth1 IP
    
    # Bootstrap with a minimal recipe because `knife bootstrap` doesn't support
    # `--force-logger` so we wouldn't have good logging. Then run `knife ssh`
    # to set and run the "real" run_list.
    
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    
    # Upload required secret keys
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/

    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa

# Recreate Production

    # Create Server (see previous section): db1.myplaceonline.com, Fedora, 2GB, San Francisco, 45.55.115.9
    ENVIRONMENT=production; NODE=db1; ROLE=db_server
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa
    
    # Create Server (see previous section): db2.myplaceonline.com, Fedora, 2GB, San Francisco, 45.55.113.250
    ENVIRONMENT=production; NODE=db2; ROLE=db_server_backup
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa

    # Create Server (see previous section): web1.myplaceonline.com, Fedora, 1GB, San Francisco, 45.55.115.198
    ENVIRONMENT=production; NODE=web1; ROLE=web_server
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa

    # Creating web1 will initialize the database. Change root@myplaceonline.com password. Create invite codes

    # Create Server (see previous section): web2.myplaceonline.com, Fedora, 1GB, San Francisco, 138.68.192.148
    ENVIRONMENT=production; NODE=web2; ROLE=web_server
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa

    # Create Server (see previous section): frontend1.myplaceonline.com, Fedora, 1GB, San Francisco, 138.68.192.106
    ENVIRONMENT=production; NODE=frontend1; ROLE=frontend_server
    knife bootstrap ${NODE}.myplaceonline.com -y --ssh-user root --identity-file ~/.ssh/id_rsa --node-name ${NODE} --run-list "recipe[bootstrap_server]" -E ${ENVIRONMENT} && sleep 120
    scp secret_key_databag_globalsecrets root@${NODE}.myplaceonline.com:/etc/myplaceonline/
    knife ssh "name:${NODE}" "chef-client --force-logger -r 'role[${ROLE}]'" --ssh-user root --identity-file ~/.ssh/id_rsa

# List nodes

    knife search "chef_environment:production"

# Add cookbook to node

    knife node run_list add $NODE recipe[server_db]

# Run cookbooks on node

    knife ssh "name:${NODE}" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa

# View Node Info

    EDITOR=cat knife node edit $NODE

# View Node JSON

    knife node show -l $NODE

# Delete Node

    knife node delete -y $NODE
    knife client delete -y $NODE

# Find all nodes of a particular role and environment

    knife search "role:db_server AND chef_environment:production"

# Create data bag

    knife data bag create $DATABAG

# Save data bag

    knife data bag from file $DATABAG $DATABAG.json

# Create encrypted data bag

    DATABAG=...
    export EDITOR=vi
    openssl rand -base64 512 | tr -d '\r\n' > secret_key_databag_$DATABAG
    knife data bag create $DATABAG $DATABAG --secret-file secret_key_databag_$DATABAG

# Show encrypted data bag

    DATABAG=globalsecrets
    knife data bag show $DATABAG $DATABAG --secret-file secret_key_databag_$DATABAG

# Edit encrypted data bag

    export EDITOR=vi
    DATABAG=globalsecrets
    knife data bag edit $DATABAG $DATABAG --secret-file secret_key_databag_$DATABAG

# Common Operations

    Update website code
      knife ssh -e -C 1 "chef_environment:production AND role:web_server" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
    
    Update all non-web servers
      knife ssh -e -C 1 "chef_environment:production AND NOT role:web_server" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
    
    Update particular server
      UPDATENODE=db2; knife ssh "chef_environment:production AND name:${UPDATENODE}" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
    
    Update all servers of a particular role (e.g. frontend)
      knife ssh -e -C 1 "chef_environment:production AND role:frontend_server" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
      
    Update all servers sequentially
      knife ssh -e -C 1 "chef_environment:production" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
      
    Run a command on all servers
      knife ssh "chef_environment:production" "$COMMAND" --ssh-user root --identity-file ~/.ssh/id_rsa

# Less Common Operations

    Update all servers (note: this concurrently updates web servers, affecting availability)
      knife ssh "chef_environment:production" "chef-client --force-logger" --ssh-user root --identity-file ~/.ssh/id_rsa
