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

class Channel
  include MongoMapper::Document

  key :name, String, :required => true
  key :code, String, :required => true
  key :calendar_id, String
  key :created_at, Time, :default => Time.now
  many :shows
end

class Show
  include MongoMapper::Document

  key :name, String
  key :description, String
  key :created_at, Time, :default => Time.now
  belongs_to :channel
end

class Schedule
  include MongoMapper::Document

  key :start_time, Time
  key :end_time, Time
  belongs_to :show
end

class Subscription
  include MongoMapper::Document

  key :show_name, String
  key :active, Boolean, :default => false
  key :cancelled, Boolean, :default => false
  key :from, Time, :default => Time.now
  belongs_to :subscriber
  belongs_to :show
end

class SMSLog
  include MongoMapper::Document

  key :external_id, Integer
  key :from, String
  key :msg, String
  key :date, Time
end

class Subscriber
  include MongoMapper::Document

  key :phone_number, String
end

module SchedulerHelper
  def get_seconds_from_min min
    return min * 60
  end

  def _get_start_of_day(time)
    Time.local(time.year, time.month, time.day, 0, 0, 0)
  end

  def today_at_time(hour,min)
    today = _get_start_of_day(Time.now)
    return Time.local(today.year, today.month, today.day, hour, min, 0)
  end

  def _get_end_of_day(time)
    Time.local(time.year, time.month, time.day, 23,59,59)
  end

  def _get_show_name_from_text (text)
    text.downcase.split(/tivi/)[1].strip
  end

  def get_schedule_for_day(time, channel)
    start_of_day = _get_start_of_day(time)
    end_of_day = _get_end_of_day(time)
    Schedule.all(:start_time => { '$gte' => start_of_day.utc },:end_time => { '$lte' => end_of_day.utc }, :show_id => { '$in' => Show.all(:channel_id => channel.id).collect { |s| s.id }  })
  end

  def sync_shows (service, calendar, day=Time.now)
    start_of_day = _get_start_of_day(day)
    end_of_day = _get_end_of_day(day)

    events = GCal4Ruby::Event.find service, {}, {
        :calendar => calendar,
        'start-min'=> start_of_day.utc.xmlschema,
        'start-max' => end_of_day.utc.xmlschema }


    events.collect { |event|
      {
        :name =>  event.title,
        :start_time => event.start_time,
        :end_time => event.end_time
      }
    }
  end

  def create_debug_shows (channel)
    nine_thirty_am_show = Show.create(:channel => channel, :name=> "9.30 AM Show", :description => "30 min show starting at 9.30 AM")
    ten_show = Show.create(:channel => channel, :name=> "10 AM Show", :description => "30 min show starting at 10.00 AM")
    ten_thirty_show = Show.create(:channel => channel, :name=> "10.30 AM Show", :description => "30 min show starting at 10.30 AM")

    Schedule.create!(:start_time => today_at_time(9,30), :end_time => today_at_time(10,00), :show => nine_thirty_am_show)
    Schedule.create!(:start_time => today_at_time(10,00), :end_time => today_at_time(10,30), :show => ten_show)
    Schedule.create!(:start_time => today_at_time(10,30), :end_time => today_at_time(11,00), :show => ten_thirty_show)
  end

  def create_schedule(service, channel)
    shows = sync_shows(service, channel.calendar_id)
    shows.each{ |_show|
      show = Show.find_by_name_and_channel_id(_show[:name], channel.id)
      if show.nil?
        show = Show.create(:name => _show[:name], :channel => channel)
      end

      schedule = Show.find_by_show_id_and_start_time(show.id, _show[:start_time])
      if schedule.nil?
        schedule = Schedule.create!(:start_time => _show[:start_time], :end_time => _show[:end_time], :show => show)
      end
    }
  end

  def get_shows_starting_in_duration (duration=5, from=Time.now)
    start_time = from + get_seconds_from_min(duration)
    Schedule.find_all_by_start_time(start_time.utc)
  end

  def get_reminders (duration=5, from=Time.now)
    shows = get_shows_starting_in_duration(duration,from)
    reminders = []
    shows.each { |show|
      #find any subscriptions for these shows
      subscriptions = Subscription.find_all_by_show_id(show.show.id)
      reminders.concat(subscriptions.collect { |sub|
        {
        :to => sub.subscriber.phone_number,
        :message => "Your show #{sub.show.name} starts in 5 min"
      }
      })
    }
    reminders
  end

  def get_latest_received_message_id
    last_sms = SMSLog.empty? ? nil : SMSLog.last(:order => :external_id)
    last_sms.nil? ? 385 : last_sms.external_id
  end

  def fetch_messages (service, last_received_message_id=get_latest_received_message_id)
    msgs = service.fetch_messages(last_received_message_id).reject! { |msg|
      msg.text.downcase.match(/tivi/).nil? or !SMSLog.find_by_external_id(msg.id.to_i).nil?
    }
  end


  def create_subscription(sms)
    show_name = _get_show_name_from_text(sms.text)
    subscriber = Subscriber.first_or_create(:phone_number => sms.from)

    show = Show.first(:name => {'$regex' => /#{show_name}/i })

    subscription = Subscription.new
    subscription.subscriber = subscriber
    subscription.show_name = show_name
    if !show.nil?
      existing = Subscription.find_all_by_show_id_and_subscriber_id_and_active(show.id, subscriber.id, true)
      if !existing.nil?
        subscription.show = show
        subscription.active = true
        subscription.save!
      else
        subscription = nil
      end
    else
      subscription.save!
    end
    subscription
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
    if !development?
      puts ">> we are not in the test environment"
      scheduler = Rufus::Scheduler.start_new
      valid_api = AfricasTalkingGateway.new("kimenye", "4f116c64a3087ae6d302b6961279fa46c7e1f2640a5a14a040d1303b2d98e560")


      scheduler.every '5s' do
        puts ">> About to call the africas talking service"
      end
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