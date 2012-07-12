require 'rubygems'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/rabbit'
require 'sinatra/reloader' if development?
require 'dm-core'
require 'mongo_mapper'

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

class Reminder
  include MongoMapper::Document

  key :subscription_text, String
  key :from, Time, :default => Time.now
  belongs_to :subscriber
  belongs_to :show
end

class Message
  include MongoMapper::Document

  belongs_to :subscriber
  key :message, String
end

class Subscriber
  include MongoMapper::Document

  key :phone_number, String
end

class ApiApplication < Sinatra::Base
  include Sinatra::Rabbit


  configure :development do
    register Sinatra::Reloader
    enable :logging
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    MongoMapper.database = 'tivi'
    enable :sessions
  end

  before  '/*', :request_method => [ :get ] do
    content_type :json
  end

  post "/sms_sync" do

    puts ">> body: #{request.body.string}"

    content_type :json
    status(200)
    body({
        :payload => {
            :success => "true"
        }
    }.to_json)

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

  collection :subscribers do
    description "API operatiosn for adding subscribers"

    operation :index do
      control do
        subscribers = Subscriber.all
        body(subscribers.to_json)
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
        if data.nil? or !data.has_key?('name') or !data.has_key?('code')
          status 400
        else
          channel = Channel.new
          channel.name = data['name']
          channel.code = data['code']
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
        if data.nil? or !data.has_key?('code') or !data.has_key?('name') then
          status 404
        else
          channel.code = data['code']
          channel.name = data['name']
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
            puts ">>Channel doesnt exist"
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