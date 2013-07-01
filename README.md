**YASI** - Yet Another Stupid Idea

This software acts as a glue between Puppet and Nagios while managed through NagiosQL.


Under Puppet you must build a class as:

	define yasi_monit($ostype) {

		case $ostype {
        	/(linux|freebsd)/: {
        		exec { 'conf_nagios_cacti':
            		command  => "/servers/scripts/system/hosts/global/yasi-cli.sh addhost $::hostname $::ipaddress $::fqdn default \'linux default\'",
            	}
			}

			/windows/: {
				exec { 'conf_nagios_cacti':
					path     => $::path,
					command  => "cmd.exe /c ruby C:\\servers\\scripts\\system\\hosts\\global\\yasi-cli.rb addhost $::hostname $::ipaddress ${::hostname}.%USERDNSDOMAIN% default \'windows default\' snmpmaster",
				}
			}
		}
	}
	
Host manifests must be registered as:

	exec { "conf_nagios_cacti":
    	command  => "/servers/scripts/system/hosts/global/yasi-cli.sh addhost $::hostname $::ipaddress_be $::fqdn webservers \'webservers staging\'",
    	schedule => 'daily'
  	}
  	
(readme)… to be continued