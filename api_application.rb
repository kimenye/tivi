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
require 'newrelic_rpm' if production?
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
      set :is_prod, true
      scheduler.every '5m' do
        settings.processor.process_reminders(settings.gateway, true)
      end

      timer = Rufus::Scheduler.start_new
      timer.cron '55 23 * * *' do

        next_day = settings.processor.tomorrow
        puts ">> Prepare schedule for #{next_day}"

        begin
          service = GCal4Ruby::Service.new
          service.authenticate "guide@tivi.co.ke", "sproutt1v!"

          Channel.all.each  { |channel|
            puts ">>> Preparing schedule for #{channel.code}"
            settings.processor.create_schedule(service,channel,false,next_day)
            settings.gateway.send_message("254705866564", "Synced channel #{channel.code}", Message::TYPE_SERVICE, nil, nil, false)
          }
        rescue Exception => e
          puts ">>> #{e.message}"
          puts ">>> #{e.backtrace.inspect}"
        end
      end
    else
      set :is_prod, false
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

  post '/shows/subscribers/:id' do
    show_id = params[:id]
    show = Show.find(show_id)
    data = JSON.parse(request.body.string)

    if !show.nil? and data.has_key?("phone_number")

      sub = Subscriber.find_or_create_by_phone_number(data["phone_number"])
      subscription = Subscription.find_by_show_id_and_subscriber_id(show.id,sub.id)

      if subscription.nil?
        Subscription.create(:show => show, :subscriber => sub, :active => true)
      end

      status 200
      body({:success => true}.to_json)
    else
      status 500
      body({:success => false}.to_json)
    end

  end

  get "/sms_gateway" do
    sms = settings.gateway.receive_notification(params)
    if !sms.nil?
      if !is_stop_message(sms.msg) and is_subscription(sms.msg) then
        subscription = create_subscription(sms)
        if !subscription.nil? and subscription.active == true then
          msg = "Thank you for your subscription. Reminders will be billed at 5KSH each. Sms 'STOP' to quit subscription"
          settings.gateway.send_message(subscription.subscriber.phone_number, msg, Message::TYPE_ACKNOWLEDGEMENT, subscription, subscription.show, settings.is_prod)
        end
        if !subscription.nil and subscription.misspelt == true then
          admins = Admin.all
          host = request.host_with_port
          url = "http://#{host}/admin/console/mobile"
          
          for adm in admins do
            full_url = "#{url}?admin_id=#{adm.id}&show=#{subscripion.show_name}"
            shortened_url = shorten_url(full_url);
            settings.gateway.send_message(adm.phone_number, "Click on the link to resolve the subscription: #{shortened_url}", Message::TYPE_ADMIN, nil, nil, false)
          end
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
  
  post "/resolve_subscription" do
    show_name = params[:show_name]
    show_id = params[:show_id]
    subscription_id = params[:subscription_id]
    
    show = Show.find_by_id(show_id)
    subscription = Subscription.find_by_id(subscription_id)
    subscription.show = show
    subscription.show_name = show_name
    subscription.active = true
    subscription.misspelt = false
    subscription.save!
    
    msg = "Thank you for your subscription. Reminders will be billed at 5KSH each. Sms 'STOP' to quit subscription"
    settings.gateway.send_message(subscription.subscriber.phone_number, msg, Message::TYPE_ACKNOWLEDGEMENT, subscription, subscription.show, settings.is_prod)
    
    status 200
    body({:success => true }.to_json)
  end

  collection :describe do
    description "What is this API capable of?"

    operation :index do
      description "For developers use only"

      control do
        status 200
        body({
                 :version => "1.0",
                 :is_production => production?,
                 :is_test => test?,
                 :is_development => development?,
                 :is_prod => settings.is_prod
             }.to_json)
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
            ktn = Channel.create!(:code => "KTN", :name => "Kenya Television Network", :calendar_id => "tivi.co.ke_1aku43rv679bbnj9r02coema98@group.calendar.google.com")
            ntv = Channel.create!(:code => "NTV", :name => "Nation Television Network", :calendar_id => "guide@tivi.co.ke")
            ctz = Channel.create!(:code => "CTZ", :name => "Citizen TV", :calendar_id => "tivi.co.ke_m6htn7v99d9vfsp874cm4g6bi0@group.calendar.google.com")
            # Will remove. Need them for testing
            subscriber01 = Subscriber.create(:phone_number => "254722654321")
            subscriber02 = Subscriber.create(:phone_number => "254722098765")
            show01 = Show.create(:name => "The Night Show", :description => "News and latest happenings", :channel => ktn)
            show01 = Show.create(:name => "Another Show", :description => "whatever", :channel => ntv)
            show01 = Show.create(:name => "Yet Another Show", :description => "blah blah", :channel => ctz)
            subscription01 = Subscription.create(:show_name => "The Night Show", :active => true, :subscriber => subscriber01, :show => show01)
            subscription02 = Subscription.create(:show_name => "The Nihgt Show", :active => false, :misspelt => true, :subscriber => subscriber02)
            subscription03 = Subscription.create(:show_name => "Anthr Show", :active => false, :misspelt => true, :subscriber => subscriber02)
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
        if data.nil? or !data.has_key?('show_name') or !data.has_key?('active') or !data.has_key?('cancelled') or !data.has_key?('misspelt')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          subscription = Subscription.new
          subscription.show_name = data['show_name']
          subscription.active = data['active']
          subscription.cancelled = data['cancelled']
          subscription.misspelt = data['misspelt']
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
        if data.nil? or !data.has_key?('show_name') or !data.has_key?('active') or !data.has_key?('cancelled') or !data.has_key?('misspelt')
          status 404
        else
          subscription.show_name = data['show_name']
          subscription.active = data['active']
          subscription.cancelled = data['cancelled']
          subscription.misspelt = data['misspelt']
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
          body(subscriber.id.to_s)
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
        channel = Channel.find(params[:id] )
        channel.safe_delete
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
        show = Show.find(params[:id])
        show.safe_delete
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

    collection :subscribers do

      operation :show do
        description "The subscribers that have subscribed to this show"

        control do
          subs = Subscription.find_all_by_show_id(params[:id])
          subscribers = subs.collect { |sub| sub.subscriber }

          status 200
          body(subscribers.to_json)
        end
      end
    end
  end
  
  collection :admins do
    description "API operations for managing admins"

    operation :index do
      description "Return all admins"
      control do
        admins = Admin.all
        status 200
        body(admins.to_json)
      end
    end
    
    operation :show do
      description "Get a specific admin"
      
      param :id, :string, :required
      control do
        admin = Admin.find_by_id(params[:id])
        if admin.nil?
          status 404
        else
          status 200
          body(admin.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific admin"
      
      param :id, :string, :required
      control do
        Admin.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create an admin"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('email') or !data.has_key?('password') or !data.has_key?('phone_number')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          admin = Admin.new
          admin.email = data['email']
          admin.password = data['password']
          admin.phone_number = data['phone_number']
          admin.save!
          status 200
          body(admin.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing admin"
      
      control do
        admin = Admin.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('email') or !data.has_key?('phone_number')
          status 404
        else
          admin.email = data['email']
          admin.phone_number = data['phone_number']
          if data.has_key?('password')
            admin.password = data['password']
          end
          admin.save!
          status 200
          body(admin.id.to_s)
        end
      end
    end
  end
  
  collection :messages do
    description "API operations for managing messages"

    operation :index do
      description "Return all messages"
      control do
        messages = Message.all
        status 200
        body(mesages.to_json)
      end
    end
    
    operation :show do
      description "Get a specific message"
      
      param :id, :string, :required
      control do
        message = Message.find_by_id(params[:id])
        if message.nil?
          status 404
        else
          status 200
          body(message.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific message"
      
      param :id, :string, :required
      control do
        Message.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create a message"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('external_id') or !data.has_key?('message_text') or !data.has_key?('type') or !data.has_key?('sent')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          message = Message.new
          message.external_id = data['external_id']
          message.message_text = data['message_text']
          message.type = data['type']
          message.sent = data['sent']
          message.save!
          status 200
          body(message.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing message"
      
      control do
        message = Message.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('external_id') or !data.has_key?('message_text') or !data.has_key?('type') or !data.has_key?('sent')
          status 404
        else
          message.external_id = data['external_id']
          message.message_text = data['message_text']
          message.type = data['type']
          message.sent = data['sent']
          message.save!
          status 200
          body(message.id.to_s)
        end
      end
    end
  end
  
  collection :adminlogs do
    description "API operations for managing admin logs"

    operation :index do
      description "Return all admin logs"
      control do
        adminlogs = AdminLog.all
        status 200
        body(adminlogs.to_json)
      end
    end
    
    operation :show do
      description "Get a specific admin log"
      
      param :id, :string, :required
      control do
        adminlog = AdminLog.find_by_id(params[:id])
        if adminlog.nil?
          status 404
        else
          status 200
          body(adminlog.to_json)
        end
      end
    end
    
    operation :destroy do
      description "Delete a specific admin log"
      
      param :id, :string, :required
      control do
        AdminLog.delete([ params[:id] ])
        body(params[:id])
      end
    end
    
    operation :create do
      description "Create an admin log"
      
      control do
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('user_text') or !data.has_key?('show_name') or !data.has_key?('user_phone_number')
          status 400
          body({error: "Invalid data"}.to_json)
        else
          adminlog = AdminLog.new
          adminlog.user_text = data['user_text']
          adminlog.show_name = data['show_name']
          adminlog.user_phone_number = data['user_phone_number']
          adminlog.save!
          status 200
          body(adminlog.id.to_s)
        end
      end
    end
    
    operation :update do
      description "Update an existing admin log"
      
      control do
        adminlog = AdminLog.find(params[:id])
        data = JSON.parse(request.body.string)
        if data.nil? or !data.has_key?('user_text') or !data.has_key?('show_name') or !data.has_key?('user_phone_number')
          status 404
        else
          adminlog.user_text = data['user_text']
          adminlog.show_name = data['show_name']
          adminlog.user_phone_number = data['user_phone_number']
          adminlog.save!
          status 200
          body(adminlog.id.to_s)
        end
      end
    end
  end

  # start the server if ruby file executed directly
  #run! if app_file == $0
end