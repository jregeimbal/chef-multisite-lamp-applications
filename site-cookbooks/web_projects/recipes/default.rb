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
  
  defaults = settings['default']

  env_settings = settings[settings_env]

  # class ::Hash
  #   def deep_merge(other_hash)
  #          self.merge(other_hash) do |key, oldval, newval|
  #            oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
  #            newval = newval.to_hash if newval.respond_to?(:to_hash)
  #            oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
  #          end
  #        end
  # end

  # env_settings.deep_merge(defaults)

  # log env_settings

  vhost_settings = settings[settings_env]["vhost"]
  app_settings = env_settings["application"]
  db_settings = env_settings["database"]
  wp_settings = env_settings["wordpress"]
  drupal_settings = settings[settings_env]["drupal"]
  yii_settings = env_settings["yii"]

  if vhost_settings
    web_app project do
      template vhost_settings['template'] || 'apache-vhost.conf.erb'
      server_name vhost_settings['server_name'] if vhost_settings["server_name"]
      server_aliases vhost_settings["server_aliases"] if vhost_settings["server_aliases"]
      docroot vhost_settings['docroot'] if vhost_settings['docroot']
    end
  end

  if yii_settings then
    include_recipe "yii"
  end

  if node["os_user"] then
    group "www-data" do
      action :modify
      members node["os_user"]
      append true
    end
  end

  # Deploy Using the PHP Wordpress Application Cookbook
  application project do
    action :deploy
    path app_settings["path"]
    owner node[:apache][:user]
    group node[:apache][:user]
    repository app_settings["repository"]
    enable_submodules true
    deploy_key app_settings["deploy_key"] if app_settings["deploy_key"]
    revision app_settings["branch"] || "master"
    packages app_settings["packages"]

    if wp_settings then
      symlinks(
        "uploads" => "wp-content/uploads",
        "wp-config.php" => "wp-config.php"
      )
      wordpress do
        local_settings_file   "wp-config.php"
        database do
          db_name       wp_settings["name"] || db_settings["name"]
          db_user       wp_settings["user"] || db_settings["user"]
          db_password   wp_settings["password"] || db_settings["password"]
          db_host       wp_settings["host"] || db_settings["host"]
          db_charset    wp_settings["charset"] || db_settings["charset"]
          db_collate    wp_settings["collate"] || db_settings["collate"]
          table_prefix  wp_settings["table_prefix"] || db_settings["table_prefix"]
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
          wp_home           wp_settings["wp_home"] 
          wp_siteurl        wp_settings["wp_siteurl"]   
          display_errors    wp_settings["display_errors"] 
          wp_debug_display  wp_settings["wp_debug_display"] 
          savequeries    wp_settings["savequeries"] 
          wp_debug  wp_settings["wp_debug"]
          wp_content_dir    app_settings["path"] + '/current/wp-content'
          wp_content_url    '/wp-content'
        end
      end
    end

    if drupal_settings then
      symlinks(
        "settings.php" => "sites/default/settings.php"
      )
      # drupal do
      #   local_settings_file   "settings.php"
      #   database do
      #     db_name       drupal_settings["name"] || db_settings["name"]
      #     db_user       drupal_settings["user"] || db_settings["user"]
      #     db_password   drupal_settings["password"] || db_settings["password"]
      #     db_host       drupal_settings["host"] || db_settings["host"]
      #     db_charset    drupal_settings["charset"] || db_settings["charset"]
      #     db_collate    drupal_settings["collate"] || db_settings["collate"]
      #     prefix        drupal_settings["table_prefix"] || db_settings["table_prefix"]
      #   end
      # end
    end
  end

  if wp_settings then
    # wordpress thing! :
    directory "wordpress upload directory" do
      path app_settings['path'] + '/shared/uploads'
      owner "www-data"
      group "www-data"
      mode 00775
      action :create
    end
  end

  execute "fixup apppath group write" do
    command "chmod -R g+w " + app_settings['path']
    # only_if { Etc.getpwuid(File.stat(vhost_settings['docroot']).uid).name != "bob" }
  end

  if db_settings then
    mysql_connection_info = {
      :host     => db_settings["host"],
      :username => 'root',
      :password => node['mysql']['server_root_password']
    }

    # Create a mysql database
    mysql_database db_settings["name"] do
      connection mysql_connection_info
      action :create
    end

    # Grant SELECT, UPDATE, and INSERT privileges to all tables in foo db from all hosts
    mysql_database_user db_settings["user"] do
      connection    mysql_connection_info
      password      db_settings["password"]
      database_name db_settings["name"]
      host          'localhost' == db_settings["host"] ? "localhost" : "%"
      privileges    [:all]
      action        :grant
    end

    if db_settings["source"] then
      source = db_settings["source"]

      if db_settings["host"] then
      
        Chef::Log.warn "Copying DB from: " + source['host']
        execute "mysql-dump-" + source['host'] do 
          command "mysqldump -h #{source['host']} -u #{source['user']} -p'#{source["password"]}' #{source['name']} > /tmp/dump.sql"
        end
        execute "mysql-load-" + source['host'] do
          command "mysql -h #{db_settings['host']} -u #{db_settings['user']} -p'#{db_settings['password']}' #{db_settings['name']} < /tmp/dump.sql"
        end
        file "/tmp/dump.sql" do
          action :delete
        end
      end
    end
  end
end


