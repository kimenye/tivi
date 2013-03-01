require 'rubygems'
require 'sinatra'
require 'haml'
require 'pry'
require_relative 'api_application'

class TiviApp < Sinatra::Base

  helpers SchedulerHelper

  configure do
    use Rack::Session::Pool, :expire_after => 86400 # 1 day
    set :protection, :except => :frame_options
  end

  get '/' do
    haml :home, :layout => :layout
  end

  get '/embed' do
    haml :embed, :layout => :embed_layout
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end
end