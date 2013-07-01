# encoding: utf-8
require 'logger'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/json'
require 'mongoid'

module Yasi

  module Confs

    class MyCfg < Sinatra::Base
      register Sinatra::ConfigFile

      if ENV['RACK_ENV'] == 'production'
        config_file '../config/config.yml'
      else
        config_file '../config/config_dev.yml'
      end

      ## use Rack::Flash
      use Rack::Session::Cookie

      @@yasi_host   = settings.yasi["host"]
      @@yasi_port   = settings.yasi["port"]
      @@yasi_domain = settings.yasi["domain"]
      @@yasi_secret = settings.yasi["session_secret"]
      @@yasi_tick   = settings.yasi["tick"]

      configure :production do
        set :sessions, :domain => "#{@@yasi_domain}" 
        set :session_secret, "#{@@yasi_secret}"
        enable :protection, :logging, :dump_errors
        enable :methodoverride
        set :root, File.dirname(__FILE__) + '/../'
        set :public_folder, File.dirname(__FILE__) + 'public'
        set :views, File.dirname(__FILE__) + '/../views'

        $logger = Logger.new(STDOUT)

        $logger.info "info: Hit configure block"

        Mongoid.configure do |config|
          name = @@mongodb_db
          config.master = Mongo::Connection.new.db(name)
          #config.logger = Logger.new($stdout, :warn) 
          #config.logger = logger
          config.persist_in_safe_mode = false
        end

      end

      configure :development, :production do
        set :sessions, :domain => "#{@@yasi_domain}" 
        set :session_secret, "#{@@yasi_secret}"
        enable :protection, :logging, :dump_errors
        enable :methodoverride
        set :root, File.dirname(__FILE__) + '/../'
        set :public_folder, File.dirname(__FILE__) + 'public'
        set :views, File.dirname(__FILE__) + '/../views'

        $logger = Logger.new(STDOUT)
        $logger.level = Logger::DEBUG

        $logger.info "INFO: Environment [#{ENV['RACK_ENV']}] defined!"

        Mongoid.load!("config/mongoid.yml")
      end


    end

  end

  module CommonHelpers

    include Rack::Utils
    alias_method :h, :escape_html

    def link_to(name, location, alternative = false)
      if alternative and alternative[:condition]
        "<a href=#{alternative[:location]}>#{alternative[:name]}</a>"
      else
        "<a href=#{location}>#{name}</a>"
      end
    end

  end

end
