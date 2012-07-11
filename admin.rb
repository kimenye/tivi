require 'rubygems'
require 'sinatra'
require_relative 'api_application'

class AdminApp < Sinatra::Base

  helpers do

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['sproutadmin', 'admin']
    end

  end

  get '/' do
    protected!
    haml :"admin/index"
  end

end