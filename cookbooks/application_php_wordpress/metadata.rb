name             "application_php_wordpress"
maintainer       "Jonathan Regeimbal"
maintainer_email "jonathan@regeimbal.net"
license          "Apache 2.0"
description      "Deploys and configures PHP-based wordpress applications"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0.0"

depends "application", "~> 3.0"
depends "application_php"
