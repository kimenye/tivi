require 'rubygems'
require 'sinatra'
require 'sinatra/json'
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

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  MongoMapper.database = 'tivi'
  enable :sessions
end

get '/' do
  haml :home, :layout => :index
end

before '/api/*' do
  content_type :json
end


post '/api/channel' do
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

get '/api/channel/:id' do
  channel = Channel.find(params[:id])
  body(channel.to_json)
end

get '/api/channels' do
  channels = Channel.all
  body(channels.to_json)
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




