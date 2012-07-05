require 'rubygems'
require 'sinatra'
require_relative 'api_application'

class TiviApp < Sinatra::Base

  get '/' do
    haml :home, :layout => :index
  end

  get '/channels' do
    haml :"channels/index", :layout => :index
  end

  get '/channels/:id' do
    channel = Channel.find(params[:id])
    haml :"channels/view", :layout => :index, :locals => {:channel => channel}
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end
end