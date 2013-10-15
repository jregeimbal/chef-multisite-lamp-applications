name             "web_projects"
maintainer       "Jonathan Regeimbal"
maintainer_email "jonathan@regeimbal.net"
license          "Apache 2.0"
description      "Uses the web_projects node attribute to configure and manage web projects"
# long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0.0"

depends 'application'
depends 'application_php'
depends 'application_php_wordpress'
depends 'mysql'
depends 'database'

%w{ debian ubuntu centos suse fedora redhat scientific amazon }.each do |os|
  supports os
end
