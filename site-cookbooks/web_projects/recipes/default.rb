#
# Author:: Jonathan Regeimbal (<jonathan@regeimbal.net>)
# License:: Apache License, Version 2.0
#
# This recipe can build out Wordpress sites from a list of web_projects.
# It gets the configuration data from matching data bag items for now.
#

include_recipe "database::mysql"

# Adjust for Chef Solo
settings_env = Chef::Config[:solo] ? "development" : node.chef_environment

node["web_projects"].split(",").each do |project|

  # Grab the settings from the "applications::[project]" data bag
  settings = data_bag_item('applications', project)
  
  if settings[settings_env]["vhost"]
    vhost_settings = settings[settings_env]["vhost"]

    web_app project do
      template vhost_settings['template'] || 'apache-vhost.conf.erb'
      server_name vhost_settings['server_name'] if vhost_settings["server_name"]
      server_aliases vhost_settings["server_aliases"] if vhost_settings["server_aliases"]
      docroot vhost_settings['docroot'] if vhost_settings['docroot']
    end
  end
  #stuff

  db_settings = settings[settings_env]["database"]
  wp_settings = settings[settings_env]["wp_params"]
  
  # Deploy Using the PHP Wordpress Application Cookbook
  application project do
    action :deploy
    path wp_settings["path"]
    owner node[:apache][:user]
    group node[:apache][:user]
    repository "https://github.com/WordPress/WordPress.git"
    enable_submodules true
    # deploy_key "-----BEGIN RSA PRIVATE KEY-----[KEY IN HERE]-----END RSA PRIVATE KEY-----"
    revision "master"
    symlinks(
      "uploads" => "wp-content/uploads",
      "wp-config.php" => "wp-config.php"
    )
   
    wordpress do
      local_settings_file   "wp-config.php"
      database do
        db_name       db_settings["db_name"]
        db_user       db_settings["db_user"]
        db_password   db_settings["db_password"]
        db_host       db_settings["db_host"]
        db_charset    db_settings["db_charset"]
        db_collate    db_settings["db_collate"]
        table_prefix  db_settings["table_prefix"]
      end
      wp_params do
        auth_key          wp_settings["auth_key"] == 'RANDOM' ? secure_password : wp_settings["auth_key"]
        secure_auth_key   wp_settings["secure_auth_key"]  == 'RANDOM' ? secure_password : wp_settings["secure_auth_key"]
        logged_in_key     wp_settings["logged_in_key"]  == 'RANDOM' ? secure_password : wp_settings["logged_in_key"]
        nonce_key         wp_settings["nonce_key"] == 'RANDOM' ? secure_password : wp_settings["nonce_key"]
        auth_salt         wp_settings["auth_salt"] == 'RANDOM' ? secure_password : wp_settings["auth_salt"]
        secure_auth_salt  wp_settings["secure_auth_salt"] == 'RANDOM' ? secure_password : wp_settings["secure_auth_salt"]
        logged_in_salt    wp_settings["logged_in_salt"]  == 'RANDOM' ? secure_password : wp_settings["logged_in_salt"]
        nonce_salt        wp_settings["nonce_salt"] == 'RANDOM' ? secure_password : wp_settings["nonce_salt"]
        wp_lang           wp_settings["wp_lang"]   
        display_errors    wp_settings["display_errors"] 
        wp_debug_display  wp_settings["wp_debug_display"] 
        savequeries    wp_settings["savequeries"] 
        wp_debug  wp_settings["wp_debug"]
        wp_content_dir    wp_settings["path"] + 'current/wp-content'
        wp_content_url    '/wp-content'
      end
    end
  end

  mysql_connection_info = {
    :host     => db_settings["db_host"],
    :username => 'root',
    :password => node['mysql']['server_root_password']
  }

  # Create a mysql database
  mysql_database db_settings["db_name"] do
    connection mysql_connection_info
    action :create
  end

  # Grant SELECT, UPDATE, and INSERT privileges to all tables in foo db from all hosts
  mysql_database_user db_settings["db_user"] do
    connection    mysql_connection_info
    password      db_settings["db_password"]
    database_name db_settings["db_name"]
    host          'localhost' == db_settings["db_host"] ? "localhost" : "%"
    privileges    [:select,:update,:insert,:create,:delete]
    action        :grant
  end
end


