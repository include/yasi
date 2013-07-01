# encoding: utf-8
require "selenium/server"
require "selenium-webdriver"
require "resque/server"
require File.dirname(__FILE__) + "/helpers.rb"

# TODO: Finish document code with RDoc

MONGODB_HOST_DOC_VERSION  = 3
MONGODB_QUEUE_DOC_VERSION = 1

include Selenium

module Yasi

  module Nagiosql

    module Burnhost

      def self.authselenium
        $logger.info "info: Selenium: authenticating..."
        @@driver = Selenium::WebDriver.for(
          :remote,
          :url => "#{$SELENIUM_HOST}:#{$SELENIUM_PORT}/#{$SELENIUM_URI}",
          :desired_capabilities => $CAPABILITIES)
        @@driver.manage.timeouts.implicit_wait = 60
        @@driver.navigate.to "#{$NAGIOSQL_HOST}/#{$NAGIOSQL_URI}"
        element = @@driver.find_element(:name, 'tfUsername')
        element.send_keys "#{$NAGIOSQL_USR}"
        element = @@driver.find_element(:name, 'tfPassword')
        element.send_keys "#{$NAGIOSQL_PAS}"
        element.submit
      end


      def self.addhostgroup(hostgroupname, hostgroupdesc)
        $logger.info "info: Seleniun: adding hostgroup..."
        authselenium
        @@driver.navigate.to "#{$NAGIOSQL_HOST}/#{$NAGIOSQL_URI}/admin/hostgroups.php"
        element = @@driver.find_element(:id, 'subAdd').click
        element = @@driver.find_element(:name, 'tfName')
        element.send_keys "#{hostgroupname}"
        element = @@driver.find_element(:name, 'tfFriendly')
        element.send_keys "#{hostgroupdesc}"
        element = @@driver.find_element(:id, 'subForm').click
        @@driver.close
      end


      ##
      # Receives arguments and passes them to CACTI CLI through remote SSH command.

      def self.addcacti(hostname, address, cacti_template_id, snmpcommunity, hostgroup)

       puts exec = `ssh -o "StrictHostKeyChecking no" -i #{$CACTI_SSHKEY} #{$CACTI_USR}@#{$CACTI_HOST} #{$CACTI_PATH}/#{$CACTI_SCRIPT} adddevice #{hostname} #{address} #{cacti_template_id} #{snmpcommunity} #{hostgroup}`

       $logger.info "info: Cacti: end add host to cacti #{exec} [ hostname:#{hostname} address:#{address} hostgroup:#{hostgroup} snmpcommunity:#{snmpcommunity}]"
      end


      ##
      # This method receives every argument needed by NagiosQL and passes them to Selenium @@driver which will
      # create a simple host, defining automatically a check_ping command for that host.

      def self.addhost(hostname, address, fqdn, hostgroup, hostgroupdesc, snmpcommunity, operatingsystem)
        description = Array.new
        description = fqdn
        $logger.info "info: Selenium: Adding host... [ hostname:#{hostname} address:#{address} description:#{description} hostgroup:#{hostgroup} snmpcommunity:#{snmpcommunity}]"

        # Run nagiosql auth form.
        authselenium

        # Opens Admin hosts uri.
        @@driver.navigate.to "#{$NAGIOSQL_HOST}/#{$NAGIOSQL_URI}/admin/hosts.php"

        # Add host click
        element = @@driver.find_element(:id, 'subAdd').click

        # Fill in host arguments
        element = @@driver.find_element(:id, 'tfName')
        element.send_keys "#{hostname}"
        element = @@driver.find_element(:id, 'tfFriendly')
        element.send_keys "#{description}"
        element = @@driver.find_element(:id, 'tfAddress')
        element.send_keys "#{address}"

        # Add check command (check_ping). One may change this in config/config.yml.
        select = @@driver.find_element(:id => "selHostCommand")             
        option = select.find_elements(:tag_name => "option").find { |o| o.text == "#{$NAGIOSQL_CMD}" }
        raise "could not find the right option" if option.nil?
        option.click 

        # Fill in check comamnd arguments
        element = @@driver.find_element(:id, 'tfArg1')
        element.send_keys "100.0,20%"
        element = @@driver.find_element(:id, 'tfArg2')
        element.send_keys "500.0,60%"

        # Choose and insert template used on this host. (default)
        element = @@driver.find_element(:name, 'butTemplDefinition').click

        # Click save host
        element = @@driver.find_element(:id, 'subForm1').click
        
        # Warning: You have not filled in all command arguments (ARGx) for your selected command
        element = @@driver.find_element(:id, 'yui-gen10-button').click

        @@driver.close


        ##
        # Because we can receive two kinds of hosts, Linux and Windows, 
        # we must verify which cacti device template to use based on operatingsystem type.

        cacti_template_id = Array.new

        case operatingsystem
          when /Linux|Debian|CentOS/  then cacti_template_id = $CACTI_NIX_TEMPLID
          when /Windows/              then cacti_template_id = $CACTI_WIN_TEMPLID
          else $logger.info "ERROR: Operating System not defined!"
        end

        addcacti(hostname, address, cacti_template_id, snmpcommunity, hostgroup)

      end

    end


    module AfterJob

      ##
      # This method runs after the resque job is complete and changes the host status field to 'registered'.

      def after_perform(h)
        $logger.info "info: Redis: Job done"
        hostname = h['hostname']
        Host.update_status(hostname)
      end
    end


    class Host
      extend AfterJob

      include Mongoid::Document
      include Mongoid::Timestamps

      field :hostname, type: String
      field :address, type: String
      field :fqdn, type: String
      field :hostgroup, type: String
      field :hostgroupdesc, type: String
      field :snmpcommunity, type: String
      field :status, type: String
      field :puppet_url, type: String
      field :operatingsystem, type: Strign
      field :doc_version, type: Integer, default: -> { MONGODB_HOST_DOC_VERSION }

      validates_presence_of :hostname, :address, :fqdn, :hostgroup
      validates_uniqueness_of :hostname, :address


      ##
      # Update host status method

      def self.update_status(hostname)
        status = "registered"
        if Host.where(hostname: hostname).update_all(status: status)
          $logger.info "info: Mongodb: Update [#{hostname}] status successful"
        else
          $logger.warn "WARNING: Mongodb: Update [#{hostname}] status failed"
        end
      end

 
      # Resque working queue

      @queue = :burnhosts


      ##
      # Method to start the resque dirty job

      def self.perform(h)

        h['status'] = "building"

        hostname        = h['hostname']
        address         = h['address']
        fqdn            = h['fqdn']
        hostgroup       = h['hostgroup']
        hostgroupdesc   = h['hostgroupdesc']
        snmpcommunity   = h['snmpcommunity']
        operatingsystem = h['operatingsystem']
        status          = h['status']

        $logger.info "info: Redis: Queueing job to add host [#{hostname} #{address} #{fqdn} #{hostgroup} #{snmpcommunity} #{operatingsystem}]"
      
        Yasi::Nagiosql::Burnhost::addhost(hostname, address, fqdn, hostgroup, hostgroupdesc, snmpcommunity, operatingsystem)

      end
      
    end


    class Main < Sinatra::Base
      register Sinatra::ConfigFile
      config_file '../config/config.yml'

      use Yasi::Confs::MyCfg
      helpers Yasi::CommonHelpers
      helpers Sinatra::JSON

      set :views, File.dirname(__FILE__) + '/../views'

      # Load configurations from 'config/config.yml' and set some vars

      $SELENIUM_HOST     = settings.selenium["host"]
      $SELENIUM_PORT     = settings.selenium["port"]
      $SELENIUM_URI      = settings.selenium["uri"]

      $NAGIOSQL_HOST     = settings.nagiosql["host"]
      $NAGIOSQL_URI      = settings.nagiosql["uri"]
      $NAGIOSQL_USR      = settings.nagiosql["username"]
      $NAGIOSQL_PAS      = settings.nagiosql["password"]
      $NAGIOSQL_CMD      = settings.nagiosql["check_cmd"]

      $CACTI_HOST        = settings.cacti["host"]
      $CACTI_USR         = settings.cacti["username"]
      $CACTI_SSHKEY      = settings.cacti["ssh_key"]
      $CACTI_PATH        = settings.cacti["script_path"]
      $CACTI_SCRIPT      = settings.cacti["script"]
      $CACTI_NIX_TEMPLID = settings.cacti["template_nix_id"]
      $CACTI_WIN_TEMPLID = settings.cacti["template_win_id"]

      $SNMP_COMMUNITY    = settings.snmp["community"]

      $REDIS_HOST        = settings.redis["host"]
      $REDIS_PORT        = settings.redis["port"]

      $CAPABILITIES      = Selenium::WebDriver::Remote::Capabilities.htmlunit(
                           :browser_name          => "htmlunit",
                           :javascript_enabled    => true,
                           :css_selectors_enabled => true,
                           :takes_screenshot      => true,
                           :native_events         => true,
                           :rotatable             => false,
                           :firefox_profile       => nil,
                           :proxy                 => nil)

      @@driver = Array.new
      @@action = String.new


      ##
      # This method takes 2 + n arguments and verifies if host (name) exists.
      # If (name) exists, do nothing; else use (*args) and add host to mongodb with status = queued.
      # Finally enqueue job to later burn.

      def check_document(action, name, *args)

        if action == "addhostgroup"
          if Host.where(hostgroup: "#{name}").exists?
            $logger.info "WARNING: Hostgroup [#{name}] exists!"
          else
            $logger.info "info: action: [#{action}] / name: [#{name}]"
            # TODO: addhostgroup function
          end
        elsif action == "addhost"
          if Host.where(hostgroup: "#{name}").exists?
            $logger.warn "WARNING: [#{action}] / name: [#{name}] EXISTS!"
          else
            @hostname        = name
            @address         = args[0]
            @fqdn            = args[1]
            @hostgroup       = args[2]
            @hostgroupdesc   = args[3]
            @snmpcommunity   = args[4]
            @operatingsystem = args[5]
            @status        = "queued"

            h = Host.new(hostname:        @hostname,
                         address:         @address,
                         fqdn:            @fqdn,
                         hostgroup:       @hostgroup,
                         hostgroupdesc:   @hostgroupdesc,
                         snmpcommunity:   @snmpcommunity,
                         operatingsystem: @operatingsystem,
                         status:          @status)

            # Saves host document to mongodb
            
            if h.save
              $logger.info "info: host saved [#{@hostname} #{@address} #{@fqdn}]"

              # Starts a new Resque object and opens a connection to Redis Server.

              Resque.redis = Redis.new( :host => $REDIS_HOST,
                                        :port => $REDIS_PORT,
                                        :thread_safe => true)

              # Guess what!? Enqueues the job!

              Resque.enqueue(Host, h)

              $logger.info "info: Redis: host queued [#{@hostname} #{@address} #{@fqdn} #{@snmpcommunity} #{@operatingsystem}]"
            else
              $logger.warn "WARNING: Redis: host failed to save [#{@hostname} #{@address} #{@fqdn} #{@snmpcommunity} #{@operatingsystem}]"
            end
          end
        end

      end


      # BEFORE FILERS

      before do
        headers 'Content-Type' => 'text/html; charset=utf-8'

        rpath = request.path
        pinfo = request.path_info

        # TODO: WARNING da merda se ha um parametro com a key hostgroup :)

        @@action = "addhost"      if pinfo.include? "host"
        @@action = "addhostgroup" if pinfo.include? "hostgroup"
      end


      # CONTROLLERS

      # HOME

      get '/' do
        erb  "you may use /c/hostgroup or /c/host/ with its params", {:layout => :layout}
      end

# NOTE: Re-factor this block to addhostgroups in a clever way!

=begin
      # HOSTGROUP

      get '/c/hostgroup' do
         json({
          :msg => "Sample command",
          :cmd => "curl -i -d groupname=LOL&hostgroupdesc=BITCH' http://127.0.0.1:9393/nagiosql/c/hostgroup"
        }, :encoder => :to_json, :content_type => :js)
      end

      post '/c/hostgroup' do
        hostgroupname = params[:hostgroupname]
        hostgroupdesc = params[:hostgroupdesc]

        addhostgroup(hostgroupname, hostgroupdesc)

        erb "Hostgroup created"
      end
=end


      # HOSTS
      #

      get '/c/host/:hostname/:address/:fqdn/:hostgroup/:hostgroupdesc' do
        name          = params[:hostname]
        address       = params[:address]
        fqdn          = params[:fqdn]
        hostgroup     = params[:hostgroup]
        hostgroupdesc = params[:hostgroupdesc]

        check_document(@@action, name, address, fqdn, hostgroup, hostgroupdesc)
      end

      post '/c/host' do
        name            = params[:hostname]
        address         = params[:address]
        fqdn            = params[:fqdn]
        hostgroup       = params[:hostgroup]
        hostgroupdesc   = params[:hostgroupdesc]
        snmpcommunity   = params[:snmpcommunity]
        operatingsystem = params[:operatingsystem]

        check_document(@@action, name, address, fqdn, hostgroup, hostgroupdesc, snmpcommunity, operatingsystem)

        redirect '/nagiosql/host/list'
      end
      
      get '/e/host/:id' do
        @h = Host.find(params[:id])
        erb :hostedit
      end
      
      put '/e/host/:id' do
        @h = Host.find(params[:id])
        @h.update_attributes(params[:host])  # receives nested values
        redirect '/nagiosql/host/list'
      end

      get '/host/list' do

        # TODO: Finish sorting by date

        begin_migration = Time.local(2011, "nov", 1)

        condition = Host.where( :created_at.gte => begin_migration,
                                :created_at.lte => Date.today.at_end_of_month).selector

        @h = Host.all
        erb :hostlist
      end

      delete '/d/host/:id' do
        h = Host.find(params[:id])
      if h.delete
        redirect '/nagiosql/host/list'
      else
        "Error deleting host"
      end

    end

      # AFTER FILTERS
      after do
        $logger.info response.status
      end

    end

  end

end
