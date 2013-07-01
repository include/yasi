require 'bundler/setup'
Bundler.require(:default)

require File.dirname(__FILE__) + "/main.rb"
require File.dirname(__FILE__) + "/lib/nagiosql.rb"

require 'resque/tasks'

desc "resque Worker"
task "resque:setup" do
	ENV['QUEUE'] = '*'
	
	Resque.redis = Redis.new(	:host => 'localhost',
								:port => 6379,
								:thread_safe => true )
end