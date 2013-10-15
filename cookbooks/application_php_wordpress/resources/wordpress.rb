#
# Cookbook Name:: application_php_wordpress
# Resource:: wordpress
#
 
# A WordPress Specific PHP Resource
 
include ApplicationPhpCookbook::ResourceBase
 
attribute :wp_params, :kind_of => Hash, :default => {} 
 
attribute :local_settings_file, :kind_of => [String, NilClass], :default => 'wp-config.php'
attribute :write_settings_file, :kind_of => [TrueClass, FalseClass], :default => true
# Actually defaults to "#{local_settings_file_name}.erb", but nil means it wasn't set by the user
attribute :settings_template, :kind_of => [String, NilClass], :default => nil
 
def local_settings_file_name
  @local_settings_file_name ||= local_settings_file.split(/[\\\/]/).last
end
 
def wp_params(*args, &block)
  @wp_params ||= Mash.new
  @wp_params.update(options_block(*args, &block))
end
 
def database(*args, &block)
  @database ||= Mash.new
  @database.update(options_block(*args, &block))
end