require 'rubygems'
require 'sinatra'
require_relative 'api_application'
require 'google/api_client'

class TiviApp < Sinatra::Base

  configure do
    use Rack::Session::Pool, :expire_after => 86400 # 1 day
  end

  get '/' do
    haml :home, :layout => :layout
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end
end