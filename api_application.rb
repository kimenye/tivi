require 'rubygems'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/rabbit'
require 'sinatra/reloader' if development?
require 'dm-core'
require 'mongo_mapper'
require 'rufus/scheduler'
require 'gcal4ruby'
require 'time'
require_relative 'AfricasTalkingGateway'
require_relative 'models'
require_relative 'scheduler'

require 'pry'

module Sinatra
  class Base
    private

    def self.request_method(*meth)
      condition do
        this_method = request.request_method.downcase.to_sym
        if meth.respond_to?(:include?) then
          meth.include?(this_method)
        else
          meth == this_method
        end
      end
    end
  end
end



class ApiApplication < Sinatra::Base
  include Sinatra::Rabbit

  helpers SchedulerHelper

  configure :development do
    register Sinatra::Reloader
    enable :logging
  end


  configure do
    set :public_folder, Proc.new { File.join(root, "static") }

    if ENV['MONGOHQ_URL']
      uri = URI.parse(ENV['MONGOHQ_URL'])
      MongoMapper.connection = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
      MongoMapper.database = uri.path.gsub(/^\//, '')
    else
      MongoMapper.database = "tivi"
    end

    enable :sessions
    puts ">>> Are we in production #{production?}"
    if production?

      scheduler = Rufus::Scheduler.start_new
      valid_api = AfricasTalkingGateway.new("kimenye", "4f116c64a3087ae6d302b6961279fa46c7e1f2640a5a14a040d1303b2d98e560")


      #scheduler.every '5s' do
        ##puts ">> About to call the africas talking service"
        #puts ">> Polling messages from Gateway"
        #SchedulerHelper.poll_subscribers(valid_api)
        #puts ">> Finished polling messages"
        #
        #puts ">>Sending reminders"
        #send_reminders(valid_api)
        #puts ">> Finished seding reminders"

      binding.pry
        hello_world("Scott")
      #end
    end
  end

  before  '/*', :request_method => [ :get ] do
    content_type :json
  end

  get "/sms_sync" do
    dbg = params[:debug]

    #check for messages
    start_time = Time.now

    if dbg == 'true'
      start_time = today_at_time(9,55)
    end
    messages = get_reminders(5,start_time)
    status(200)
    body({
      :payload => {
        :task => "send",
        :messages => messages
      }
     }.to_json)
  end

  post "/sms_sync" do
    s = SubscriptionLog.new
    s.message = request.body.string

    s.save!

    from = params[:from]
    msg = params[:message]

    #check to see if the subscriber exists
    existing_subscriber = Subscriber.first(:phone_number => from)

    if existing_subscriber.nil?
      existing_subscriber = Subscriber.new
      existing_subscriber.phone_number = from
      existing_subscriber.save!
    end

    show_name = msg.split(/TIVI/).join.lstrip.rstrip if msg =~ /TIVI/
    if show_name.nil?
      show_name = msg
    end

    subscription = Subscription.new
    subscription.subscriber = existing_subscriber

    existing_show = Show.first(:name => show_name)
    if not existing_show.nil?
      subscription.active = true
      subscription.show = existing_show
    else
      subscription.show_name = show_name
    end

    subscription.save!
    content_type :json
    status(200)
    body({
        :payload => {
            :success => "true"
        }
    }.to_json)

  end

  post "/channels/sync/:id" do
    channel_id = params[:id]
    channel = Channel.find_by_id(channel_id)
    if development? || test?
      create_debug_shows(channel)
    else
      service = GCal4Ruby::Service.new
      service.authenticate "guide@tivi.co.ke", "sproutt1v!"
      create_schedule(service,channel)
    end

    status 200
    body({ success: true}.to_json)
  end

  collection :describe do
    description "What is this API capable of?"

    operation :index do
      description "For developers use only"

      control do
        status 200
        body({ version: "1.0 "}.to_json)
      end
    end
  end

  collection :subscriptions do
    description "API for managing subscriptions"

    operation :index do
      control do
        status(200)
        body(Subscription.all.to_json)
      end
    end
  end

  collection :subscribers do
    description "API operations for adding subscribers"

    operation :index do
      control do
        subscribers = Subscriber.all
        body(subscribers.to_json)
      end
    end
  end

  collection :log do

    operation :index do
      control do
        l = SubscriptionLog.all
        body(l.to_json)
      end
    end
  end


  collection :channels do
    description "API operations for a TV channel"

    operation :index do
      description "Return a list of all the channels"
      param :limit, :string
      control do
        channels = Channel.all
        body(channels.to_json)
      end
    end


    operation :show do
      description "Show a specific channel"
      param :id,  :string, :required
      control do
        channel = Channel.find(params[:id])
        body(channel.to_json)
      end
    end

    collection :shows do
      operation :show do
        description "Return only the shows for this channel"

        param :id,  :string, :required
        control do
          channel = Channel.find(params[:id])
          body(channel.shows.to_json)
        end
      end
    end

    collection :schedule do
      operation :show do
        description "Returns the scheduled shows for this channel for the current day"

        param :id, :string, :required
        control do
          channel = Channel.find(params[:id])
          day = params[:when] ? Time.parse(params[:when]) : Time.now
          schedule = get_schedule_for_day(day, channel)
          status(200)
          body(schedule.to_json)
        end
      end
    end

    operation :destroy do
      description "Delete a specific channel"
      param :id, :string, :required
      control do
        Channel.delete([ params[:id] ])
        body(params[:id])
      end
    end

    operation :create do
      description "Create a new channel"
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('name') or !data.has_key?('code') or !data.has_key?('calendar_id')
          status 400
        else
          channel = Channel.new
          channel.name = data['name']
          channel.code = data['code']
          channel.calendar_id = data['calendar_id']
          channel.save!
          status 200
          body(channel.id.to_s)
        end
      end
    end

    operation :update do
      description "Updates an existing channel"
      control do
        channel = Channel.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('code') or !data.has_key?('name') or !data.has_key?('calendar_id') then
          status 404
        else
          channel.code = data['code']
          channel.name = data['name']
          channel.calendar_id = data['calendar_id']
          channel.save!
          status 200
          body(channel.id.to_s)
        end
      end
    end
  end


  collection :shows do
    description "API operations for a TV Show"

    operation :index do
      description  "Return all TV Shows"
      control do
        shows = Show.all
        status 200
        body(shows.to_json)
      end
    end

    operation :show do
      description "Get a specific TV Show"

      param :id, :string, :required
      control do
        show = Show.find_by_id(params[:id])
        if show.nil?
          status 404
        else
          status 200
          body(show.to_json)
        end
      end
    end

    operation :destroy do
      description "Delete a specific show"
      param :id, :string, :required
      control do
        Show.delete([ params[:id] ])
        body(params[:id])
      end
    end

    operation :create do
      description "Create a TV show"

      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('description') or !data.has_key?('name') or !data.has_key?('channel') then
          status 404
          body({error: "Invalid data"}.to_json)
        else
          channel = Channel.find(data['channel'])
          if !channel.nil? then
            show = Show.new
            show.name = data['name']
            show.description = data['description']
            show.channel = channel
            show.save!
            status 200
            body(show.id.to_s)
          else
            status 400
            body({error: "That channel does not exist"})
          end
        end
      end
    end

    operation :update do
      description "Updates an existing show"
      control do
        show = Show.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('description') or !data.has_key?('name') then
          status 404
        else
          channel = Channel.find(data['channel'])
          show.name = data['name']
          show.description = data['description']
          show.channel = channel if !channel.nil?
          show.save!
          status 200
          body(show.id.to_s)
        end
      end
    end
  end

  # start the server if ruby file executed directly
  #run! if app_file == $0
end