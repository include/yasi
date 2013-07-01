# yasi-cli.rb - Command Line Helper to YASI webservice.
#               This script should be run by Puppet on every host.
#               Puppet will fill in every argument with host facts and 
#               yasi-cli post them to YASI webservice.
# Version - 0.2
# Date 14/Ago/2012 - <francisco.cabrita@gmail.com

require 'rubygems'
require 'rbconfig'
require 'net/http'
require 'uri'
require 'logger'

# Fetch params from Ruby build

targ_cpu  = RbConfig::CONFIG['target_cpu']
targ_os   = RbConfig::CONFIG['target_os']
host_cpu  = RbConfig::CONFIG['host_cpu']
host_os   = RbConfig::CONFIG['host_os']
@ruby_ver = RbConfig::CONFIG['ruby_version']

@@yasiHost   = 'localhost'
@@yasiPort   = '9393'
@@addHostUri = '/nagiosql/c/host'
@@yasiUser   = 'USER'
@@yasiPass   = 'CHANGEME'

# Verifies if script is running on Linux or Windows hosts and changes the log path

if host_os =~ /linux/
  @@logger = Logger.new('/servers/logs/yasi-cli-rb.log', 'weekly')
elsif host_os =~ /(msin|mingw)/
  @@logger = Logger.new('C:\servers\logs\yasi-cli-rb.log', 'weekly')
else
  @@logger = Logger.new('yasi-cli-rb.log', 'weekly')
end

action          = ARGV[0].dup.downcase unless ARGV[0].nil?
hostname        = ARGV[1].dup.downcase unless ARGV[1].nil?
address         = ARGV[2].dup.downcase unless ARGV[2].nil?
fqdn            = ARGV[3].dup.downcase unless ARGV[3].nil?
hostgroup       = ARGV[4].dup.downcase unless ARGV[4].nil?
hostgroupdesc   = ARGV[5].dup.downcase unless ARGV[5].nil?
snmp_community  = ARGV[6].dup.downcase unless ARGV[6].nil?
operatingsystem = ARGV[7].dup.downcase unless ARGV[7].nil?

snmp_default_community = "snmpcom"

snmp_community = snmp_default_community unless snmp_community.nil?
#hostgroupdesc_clean = hostgroupdesc.gsub(/[\s]+/, '%20') unless hostgroupdesc == nil

def help
  puts "\nUsage:"
  puts "  yasi-cli.rb help"
  puts "  yasi-cli.rb addhost hostname ip fqdn hostgroup hostgroupdesc <snmpcommunity> operatingsystem\n"
  puts ""
  puts "Optional"
  puts "  snmpcommunity defaults to 'snmpcom'"
  puts ""
  puts "Example:"
  puts " ./yasi-cli.rb addhost lolcat 127.0.0.1 lolcat.domain.tld lolcats \"lolcats servers\" snmpmaster Debian\n\n"
end

##
# MEthod to Verify if every argument needed is present.

def validateCmd
  if (ARGV.length < 8)
    puts "\nExiting: Please fill all the arguments [#{ARGV.length} of 8]\n"
    @@logger.error('Error') {"Argument error"}
    help
    @@logger.close
    Kernel.exit(1)
  end
end

validateCmd

##
# Addhost method baked to handle a payload or arguments.
# Authentication goes here too.

def addhost(hostname, address, fqdn, hostgroup, hostgroupdesc, snmp_community, operatingsystem) 

  payload = { "hostname"        => hostname,
              "address"         => address,
              "fqdn"            => fqdn,
              "hostgroup"       => hostgroup,
              "hostgroupdesc"   => hostgroupdesc,
              "snmpcommunity"   => snmp_community,
              "operatingsystem" => operatingsystem }

  uri = URI("http://#{@@yasiHost}:#{@@yasiPort}#{@@addHostUri}")

  request = Net::HTTP::Post.new(uri.request_uri)

  request.basic_auth @@yasiUser, @@yasiPass

  request.set_form_data(payload)

  res = Net::HTTP.start(@@yasiHost, @@yasiPort) do |http|
    http.request(request)
  end

  if res.to_s.include? "HTTPUnauthorized"
    @@logger.error('Error') {"Authentication failed"}
  else
    @@logger.info('AddingHost') {payload}
  end

  @@logger.close

  Kernel.exit(0)
end


case action
  when "addhost" then addhost(hostname, address, fqdn, hostgroup, hostgroupdesc, snmp_community, operatingsystem)
  when "help"    then help
  else
    puts "Unrecognized action"
    help
end