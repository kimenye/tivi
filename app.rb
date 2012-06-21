require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'mongo'

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

get '/' do
  haml :home, :layout => :index
end

get '/upcoming' do

end

