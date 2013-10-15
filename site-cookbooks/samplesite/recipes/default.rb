web_app 'samplesite' do
  server_name "samplesite.com"
  # server_aliases [node['fqdn'], "www.samplesite.com"]
  server_aliases [node['fqdn'], "samplesite.localhost"]
  docroot node['wordpress']['dir']
  template "samplesite.conf.erb"
end

directory node['wordpress']['dir'] do
  owner "www-data"
  group "www-data"
  mode 00775
  action :create
  recursive true
end

include_recipe 'wordpress'  # This is a Wordpress recipe which will create the wp-config from the samplesite attributes default.rb

# Now we create the Database
mysql_connection_info = {
  :host     => 'localhost',
  :username => 'root',
  :password => node['mysql']['server_root_password']
}

# Create a mysql database
mysql_database 'samplesite_wp' do
  connection mysql_connection_info
  action :create
end

# Grant SELECT, UPDATE, and INSERT privileges to all tables in foo db from all hosts
mysql_database_user node['wordpress']['db']['user'] do
  connection    mysql_connection_info
  password      node['wordpress']['db']['password']
  database_name node['wordpress']['db']['database']
  host          '%'
  privileges    [:select,:update,:insert]
  action        :grant
end

# This shows how to pull a repo from github
# git default['wordpress']['dir'] do
#   repository "https://user:password@github.com/jregeimbal/samplesite.git"
#   user "www-data"
#   group "www-data"
#   reference "master"
#   action :sync
#   # ssh_wrapper "/tmp/ssh_wrapper.sh"
# end

