# encoding: utf-8
require "selenium/server"
require "selenium-webdriver"
require "resque/server"
require File.dirname(__FILE__) + "/helpers.rb"

MONGODB_HOST_DOC_VERSION  = 1
MONGODB_QUEUE_DOC_VERSION = 1
 
include Selenium

module Yasi

  module Nagiosql

    module Burnhost

      def self.authselenium
        $logger.info "info: authenticating..."
        @@driver = Selenium::WebDriver.for(
          :remote,
          :url => "#{$SELENIUM_HOST}:#{$SELENIUM_PORT}/#{$SELENIUM_URI}",
          :desired_capabilities => $CAPABILITIES)
        @@driver.navigate.to "#{$NAGIOSQL_HOST}/#{$NAGIOSQL_URI}"
        element = @@driver.find_element(:name, 'tfUsername')
        element.send_keys "#{$NAGIOSQL_USR}"
        element = @@driver.find_element(:name, 'tfPassword')
        element.send_keys "#{$NAGIOSQL_PAS}"
        element.submit
      end

      def self.addhostgroup(hostgroupname, hostgroupdesc)
        $logger.info "info: adding hostgroup..."
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

     def self.addcacti(hostname, address, template_id, snmp_community, hostgroup)
       $logger.info "info: init add host to cacti"
       $logger.info "#{hostname} #{address} #{hostgroup}"

       # exec = `ssh cabrita@nagios3 'ls /var/log ; touch /tmp/lol'`
      
       puts exec = `ssh -o "StrictHostKeyChecking no" -i #{$CACTI_SSHKEY} #{$CACTI_USR}@#{$CACTI_HOST} #{$CACTI_PATH}/#{$CACTI_SCRIPT} adddevice #{hostname} #{address} #{$CACTI_TEMPLID} company #{hostgroup}`

       $logger.info "info: end add host to cacti #{exec}"
     end
 
      def self.addhost(hostname, address, fqdn, hostgroup, hostgroupdesc)
        description = Array.new
        description = fqdn
        $logger.info "info: Running stuff on selenium... [#{hostname} #{address} #{description} #{hostgroup}]"
        authselenium
        @@driver.navigate.to "#{$NAGIOSQL_HOST}/#{$NAGIOSQL_URI}/admin/hosts.php"
        element = @@driver.find_element(:id, 'subAdd').click
        element = @@driver.find_element(:id, 'tfName')
        element.send_keys "#{hostname}"
        element = @@driver.find_element(:id, 'tfFriendly')
        element.send_keys "#{description}"
        element = @@driver.find_element(:id, 'tfAddress')
        element.send_keys "#{address}"
        select = @@driver.find_element(:id => "selHostCommand")             
        option = select.find_elements(:tag_name => "option").find { |o| o.text == "#{$NAGIOSQL_CMD}" }
        raise "could not find the right option" if option.nil?
        option.click 
        element = @@driver.find_element(:id, 'tfArg1')
        element.send_keys "100.0,20%"
        element = @@driver.find_element(:id, 'tfArg2')
        element.send_keys "500.0,60%"
        element = @@driver.find_element(:name, 'butTemplDefinition').click
        element = @@driver.find_element(:id, 'subForm1').click
        @@driver.close

        $logger.warn "WARNING: >>>> description= #{description} hostgroup= #{hostgroup}"

        addcacti(hostname, address, $CACTI_TEMPLID, $SNMP_COMMUNITY, hostgroup)
      end

    end

    module AfterJob

     def after_perform(h)
       $logger.info "info: Job done"
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
      field :status, type: String
      field :puppet_url, type: String
      field :doc_version, type: Integer, default: -> { MONGODB_HOST_DOC_VERSION }

      validates_presence_of :hostname, :address, :fqdn, :hostgroup
      validates_uniqueness_of :hostname, :address

       def self.update_status(hostname)
        status = "registered"
        if Host.where(hostname: hostname).update_all(status: status)
          $logger.info "info: Update [#{hostname}] status successful"
        else
          $logger.warn "WARNING: Update [#{hostname}] status failed"
        end
      end
 
      @queue = :burnhosts

      def self.perform(h)

        h['status'] = "building"

        hostname      = h['hostname']
        address       = h['address']
        fqdn          = h['fqdn']
        hostgroup     = h['hostgroup']
        hostgroupdesc = h['hostgroupdesc']
        status        = h['status']

        $logger.info "info: Queueing job to add host [#{hostname} #{address} #{fqdn} #{hostgroup}]"

        Yasi::Nagiosql::Burnhost::addhost(hostname, address, fqdn, hostgroup, hostgroupdesc)

      end
      
    end


    class Main < Sinatra::Base
      register Sinatra::ConfigFile
      config_file '../config/config.yml'

      use Yasi::Confs::MyCfg
      helpers Yasi::CommonHelpers
      helpers Sinatra::JSON

      set :views, File.dirname(__FILE__) + '/../views'

      $SELENIUM_HOST  = settings.selenium["host"]
      $SELENIUM_PORT  = settings.selenium["port"]
      $SELENIUM_URI   = settings.selenium["uri"]

      $NAGIOSQL_HOST  = settings.nagiosql["host"]
      $NAGIOSQL_URI   = settings.nagiosql["uri"]
      $NAGIOSQL_USR   = settings.nagiosql["username"]
      $NAGIOSQL_PAS   = settings.nagiosql["password"]
      $NAGIOSQL_CMD   = settings.nagiosql["check_cmd"]

      $CACTI_HOST     = settings.cacti["host"]
      $CACTI_USR      = settings.cacti["username"]
      $CACTI_SSHKEY   = settings.cacti["ssh_key"]
      $CACTI_PATH     = settings.cacti["script_path"]
      $CACTI_SCRIPT   = settings.cacti["script"]
      $CACTI_TEMPLID  = settings.cacti["template_id"]

      $SNMP_COMMUNITY = settings.snmp["community"]

      $REDIS_HOST     = settings.redis["host"]
      $REDIS_PORT     = settings.redis["port"]

      $CAPABILITIES   = Selenium::WebDriver::Remote::Capabilities.htmlunit(
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


      def check_document(action, name, *args)

        if action == "addhostgroup"
          if Host.exists?(conditions: { hostgroup: "#{name}" })
            $logger.info "WARNING: Hostgroup [#{name}] exists!"
          else
            $logger.info "info: action: [#{action}] / name: [#{name}]"
            # TODO addhostgroup function
          end
        elsif action == "addhost"
          if Host.exists?(conditions: { hostname: "#{name}" })
            $logger.warn "WARNING: [#{action}] / name: [#{name}] EXISTS!"
          else
            @hostname      = name
            @address       = args[0]
            @fqdn          = args[1]
            @hostgroup     = args[2]
            @hostgroupdesc = args[3]
            @status        = "queued"
            h = Host.new(hostname:      @hostname,
                         address:       @address,
                         fqdn:          @fqdn,
                         hostgroup:     @hostgroup,
                         hostgroupdesc: @hostgroupdesc,
                         status:        @status)

            if h.save
              $logger.info "info: host saved [#{@hostname} #{@address} #{@fqdn}]"

              Resque.redis = Redis.new(:host => '127.0.0.1', :port => 6379)

              Resque.enqueue(Host, h)
              $logger.info "info: host queued [#{@hostname} #{@address} #{@fqdn}]"
            else
              $logger.warn "WARNING: host failed to save [#{@hostname} #{@address} #{@fqdn}]"
            end
          end
        end

      end


      # // BEFORE FILERS

      before do
        headers 'Content-Type' => 'text/html; charset=utf-8'

        rpath = request.path
        pinfo = request.path_info

        @@action = "addhost"      if pinfo.include? "host"
        @@action = "addhostgroup" if pinfo.include? "hostgroup"   # TODO WARNING da merda se ha um parametro com a key hostgroup :)
      end



      # // CONTROLLERS

      # HOME

      get '/' do
        erb  "you may use /c/hostgroup or /c/host/ with its params", {:layout => :layout}
      end



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
        hostname      = params[:hostname]
        address       = params[:address]
        fqdn          = params[:fqdn]
        hostgroup     = params[:hostgroup]
        hostgroupdesc = params[:hostgroupdesc]

        check_document(@@action, name, address, fqdn, hostgroup, hostgroupdesc)
      end

      get '/host/list' do
        @h = Host.all
        slim :hostlist
      end

      delete '/d/host/:id' do
        h = Host.find(params[:id])
      if h.delete
        redirect '/nagiosql/host/list'
      else
        "Error deleting host"
      end

    end



      # // AFTER FILTERS

      after do
        $logger.info response.status
      end

    end

  end

end
