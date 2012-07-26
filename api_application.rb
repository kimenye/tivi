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
require_relative 'models'
require_relative 'scheduler'
require_relative 'sms_gateway'

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

class ReminderProcessor
  include SchedulerHelper
end

class ApiApplication < Sinatra::Base
  include Sinatra::Rabbit

  helpers SchedulerHelper

  configure :development do
    register Sinatra::Reloader
  end


  configure do
    enable :logging
    set :public_folder, Proc.new { File.join(root, "static") }

    set :gateway, RoamTechGateway.new
    set :processor, ReminderProcessor.new

    if ENV['MONGOHQ_URL']
      uri = URI.parse(ENV['MONGOHQ_URL'])
      MongoMapper.connection = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
      MongoMapper.database = uri.path.gsub(/^\//, '')
    else
      MongoMapper.database = "tivi"
    end

    enable :sessions

    if production?
      scheduler = Rufus::Scheduler.start_new
      set :scheduler, scheduler

      scheduler.every '5m' do
        settings.processor.process_reminders(settings.gateway, production?)
      end
    end
  end

  before  '/*', :request_method => [ :get ] do
    content_type :json
  end

  post "/channels/sync/:id" do
    channel_id = params[:id]
    channel = Channel.find_by_id(channel_id)
    if test?
      create_debug_shows(channel)
    else
      service = GCal4Ruby::Service.new
      service.authenticate "guide@tivi.co.ke", "sproutt1v!"
      create_schedule(service,channel)
    end

    status 200
    body({ success: true}.to_json)
  end

  get "/sms_gateway" do
    puts ">> Production #{production?} / Development #{development?} / Test #{test?}"
    sms = settings.gateway.receive_notification(params)
    if !sms.nil?
      if !is_stop_message(sms.msg) and is_subscription(sms.msg) then
        subscription = create_subscription(sms)
        if !subscription.nil? and subscription.active == true then
          msg = "Thank you for your subscription. Reminders will be billed at 5KSH each. STOP 'STOP' to quit subscription"
          settings.gateway.send_message(subscription.subscriber.phone_number, msg, Message::TYPE_ACKNOWLEDGEMENT, subscription, subscription.show, production?)
        end
      elsif is_stop_message(sms.msg) then
        deactivate_subscriptions(sms.from)
      end
    end

    status 200
    body({ success: true}.to_json)
  end

  get "/reminders" do
    user_name = params[:username]
    password = params[:password]

    if authenticate(user_name, password)
      time = Time.now
      if !production?
         time = today_at_time(9,55)
      end
      process_reminders(settings.gateway,production?, 5, time)
      status 200
      body({:success => true }.to_json)
    end
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

  collection :reset do
    description "Resets the database to a reasonable state"

    operation :index do
      control do
        user_name = params[:username]
        password = params[:password]
        create = params[:create]

        if authenticate(user_name,password)
          status 200

          Subscriber.delete_all
          Subscription.delete_all
          Schedule.delete_all
          Show.delete_all
          Channel.delete_all
          SMSLog.delete_all
          Message.delete_all

          if create == "true"
            ktn = Channel.create(:code => "KTN", :name => "Kenya Television Network", :calendar_id => "tivi.co.ke_1aku43rv679bbnj9r02coema98@group.calendar.google.com")
          end

          body({:success => true }.to_json)
        else
          status 401
          body({:error => "Invalid credentials to reset"}.to_json)
        end
      end
    end
  end

  collection :subscriptions do
    description "API for managing subscriptions"
    
    operation :index do
      description "Return all subscriptions"
      control do
        subscriptions = Subscription.all
        status 200
        body(subscriptions.to_json)
      end
    end
    
    operation :show do
      description "Get a specific subscription"
      
      param :id, :string, :required
      control do
        subscription = Subscription.find_by_id(params[:id])
        if subscription.nil?
          status 404
        else
          status 200
          body(subscription.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific subscription"
      
      param :id, :string, :required
      control do
        Subscription.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create a subscription"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('show_name') or !data.has_key?('active') or !data.has_key?('cancelled')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          subscription = Subscription.new
          subscription.show_name = data['show_name']
          subscription.active = data['active']
          subscription.cancelled = data['cancelled']
          subscription.save!
          status 200
          body(subscription.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing subscription"
      
      control do
        subscription = Subscription.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('show_name') or !data.has_key?('active') or !data.has_key?('cancelled')
          status 404
        else
          subscription.show_name = data['show_name']
          subscription.active = data['active']
          subscription.cancelled = data['cancelled']
          subscription.save!
          status 200
          body(subscription.id.to_s)
        end
      end
    end
    
  end

  collection :subscribers do
    description "API operations for managing subscribers"

    operation :index do
      description "Return all subscribers"
      control do
        subscribers = Subscriber.all
        status 200
        body(subscribers.to_json)
      end
    end
    
    operation :show do
      description "Get a specific subscriber"
      
      param :id, :string, :required
      control do
        subscriber = Subscriber.find_by_id(params[:id])
        if subscriber.nil?
          status 404
        else
          status 200
          body(subscriber.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific subscriber"
      
      param :id, :string, :required
      control do
        Subscriber.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create a subscriber"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('phone_number')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          subscriber = Subscriber.new
          subscriber.phone_number = data['phone_number']
          subscriber.save!
          status 200
          body(subscriber.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing subscriber"
      
      control do
        subscriber = Subscriber.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('phone_number')
          status 404
        else
          subscriber.phone_number = data['phone_number']
          subscriber.save!
          status 200
          body(channel.id.to_s)
        end
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

  collection :messages do
    description "API operations for managing the outgoing messages"

    operation :index do
      control do
        m = Message.all
        status 200
        body (m.to_json)
      end
    end
  end

  collection :sms do
    description "API operations for managing sms logs"

    operation :index do
      description "Return all sms logs"
      control do
        l = SMSLog.all
        status 200
        body(l.to_json)
      end
    end
    
    operation :show do
      description "Get a specific sms log"
      
      param :id, :string, :required
      control do
        l = SMSLog.find_by_id(params[:id])
        if l.nil?
          status 404
        else
          status 200
          body(l.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific sms log"
      
      param :id, :string, :required
      control do
        SMSLog.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create an sms log"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('external_id') or !data.has_key?('from') or !data.has_key?('msg')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          l = SMSLog.new
          l.external_id = data['external_id']
          l.from = data['from']
          l.msg = data['msg']
          l.save!
          status 200
          body(l.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing sms log"
      
      control do
        l = SMSLog.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('external_id') or !data.has_key?('from') or !data.has_key?('msg')
          status 404
        else
          l.external_id = data['external_id']
          l.from = data['from']
          l.msg = data['msg']
          l.save!
          status 200
          body(l.id.to_s)
        end
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