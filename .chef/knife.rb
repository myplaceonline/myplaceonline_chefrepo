# See https://docs.getchef.com/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "root"
client_key               "#{current_dir}/root.pem"
validation_client_name   "myplaceonline-validator"
validation_key           "#{current_dir}/myplaceonline-validator.pem"
chef_server_url          "https://admin.myplaceonline.com/organizations/myplaceonline"
cookbook_path            ["#{current_dir}/../cookbooks"]
