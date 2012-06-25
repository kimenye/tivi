require 'rubygems'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/rabbit'
require 'sinatra/reloader' if development?
require 'dm-core'
require 'mongo_mapper'

class Channel
  include MongoMapper::Document

  key :name, String, :required => true
  key :code, String, :required => true
  key :created_at, Time, :default => Time.now
end

class TvShow
  include MongoMapper::Document

  key :name, String
  key :description, String
  key :created_at, Time, :default => Time.now
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

  before '/*' do
    content_type :json
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

  collection :channels do
    description "API operations for a TV channel"

    operation :index do
      description "Return a list of all the channels"
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
        puts ">> Called the patch operation"
        channel = Channel.find(params[:id])

        puts ">>> updating #{channel}"
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


  #create a tv show
  post '/api/show' do
    data = JSON.parse(request.body.string)
    if data.nil?  or !data.has_key?('name') or !data.has_key?('description') then
      status 400
    else
      show = TvShow.new
      show.description = data['description']
      show.name = data['name']
      show.save!
      status 200
      body(show.id.to_s)
    end
  end


  get '/api/shows' do
    shows = TvShow.all
    body(shows.to_json)
  end

  get '/api/show/:id' do
    show = TvShow.find(params[:id])
    body(show.to_json)
  end

  # start the server if ruby file executed directly
  #run! if app_file == $0
end