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

      admin = Admin.find_by_email_and_password(email,password)

      @auth.provided? && @auth.basic? && @auth.credentials && !admin.nil?
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
    shows = Show.all
    admins = Admin.all
    misspelt_subscriptions = Subscription.find_all_by_misspelt(true)

    haml :"admin/console", :layout => :admin, :locals => {:shows => shows, :admins => admins, :misspelt_subscriptions => misspelt_subscriptions}
  end

end