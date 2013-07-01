require 'bundler/setup'
Bundler.require(:default)

require File.dirname(__FILE__) + "/main.rb"
require File.dirname(__FILE__) + "/lib/nagiosql.rb"

$stdout.sync = true

use Rack::ShowExceptions

use Rack::Auth::Basic, "Restricted Area" do |username, password|
    [username, password] == ['USER', 'PASS']
end


map('/') { run Yasi::Main }

map('/nagiosql') { run Yasi::Nagiosql::Main }

Resque.redis = Redis.new(	:host => 'localhost',
							:port => 6379,
							:thread_safe => true )

map('/resque') { run Resque::Server }