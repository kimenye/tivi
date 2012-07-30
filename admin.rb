require 'rubygems'
require 'sinatra'
require 'pry'
require_relative 'api_application'
require 'sinatra/reloader' if development? or test?

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
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['guide@tivi.co.ke', 'sproutt1v!']
    end

  end

  get '/' do
    protected!
    haml :"admin/index", :layout => :admin
  end

  get '/schedule/:id' do
    protected!
    channel = Channel.find_by_id(params[:id])
    haml :"admin/channel", :layout => :guide, :locals => { :channel => channel }
  end

  get '/subscription' do
    protected!
    subscriptions = Subscription.all
    haml :"admin/subscription", :layout => :admin, :locals => { :subscriptions => subscriptions }
  end

end