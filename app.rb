require 'rubygems'
require 'sinatra'
require 'haml'
require_relative 'api_application'

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