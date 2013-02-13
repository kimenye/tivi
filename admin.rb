require 'rubygems'
require 'sinatra'
require 'pry'
require 'haml'
require 'time'
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
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      return false unless @auth.provided?
      email = @auth.credentials.first
      password = @auth.credentials.last

      if production? || test?
        admin = Admin.find_by_email_and_password(email,password)
        @auth.provided? && @auth.basic? && @auth.credentials && !admin.nil?
      else
        true
      end
    end

  end
  helpers SchedulerHelper

  get '/' do
    protected!
    haml :"admin/index", :layout => :admin
  end

  get '/subscription' do
    protected!
    subscriptions = Subscription.all
    haml :"admin/subscription", :layout => :admin, :locals => {:subscriptions => subscriptions}
  end

  get '/message' do
    protected!
    messages = Message.all
    haml :"admin/message", :layout => :admin, :locals => {:messages => messages}
  end

  get '/channel/:id' do
    protected!
    channel = Channel.find(params[:id])
    day = params[:when] ? Time.parse(params[:when]) : Time.now
    schedule = get_schedule_for_day(day, channel)

    prev_day = yesterday(day)
    next_day = tomorrow(day)

    haml :"admin/channel", :layout => :admin, :locals => {:channel => channel, :schedule => schedule, :day => day, :prev_day => prev_day, :next_day => next_day }
  end
  
  get '/console' do
    protected!
    haml :"admin/console", :layout => :admin
  end
  
  get "/console/mobile/:admin_id" do
    admin = Admin.find(params[:admin_id])
    if admin.nil?
      throw(:halt, [401, "Not authorized\n"])
    end
    shows = Show.all
    subscriptions = Subscription.all
    misspelt = Array.new
    for subscription in subscriptions do
      if subscription.misspelt == true
        misspelt.push subscription
      end
    end
    haml :"admin/mobile", :layout => :mobile_layout, :locals => {:shows => shows, :admin_id => params[:admin_id], :misspelt => misspelt}
  end

end