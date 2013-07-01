# encoding: utf-8
require File.dirname(__FILE__) + "/lib/helpers.rb"

module Yasi

  class Main < Sinatra::Base

    use Yasi::Confs::MyCfg
    helpers Yasi::CommonHelpers

    error do
      e = request.env['sinatra.error']
      Kernel.puts e.backtrace.join("\n")
      "Application Error"
    end

    not_found do
      "Not found!"
    end

    # BEFORE FILTERS

    before do
      headers 'Content-Type' => 'text/html; charset=utf-8'
    end

    # CONTROLLERS

    get '/' do
      erb :index
    end

  end

end
