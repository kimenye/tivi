require 'rubygems'
require 'sinatra'
require_relative 'api_application'
require 'google/api_client'

class TiviApp < Sinatra::Base

  configure do
    use Rack::Session::Pool, :expire_after => 86400 # 1 day
  end

  get '/' do
    haml :home, :layout => :index
  end

  before '/admin' do
    puts ">> starting authorization process for admin access"
    @client = Google::APIClient.new
    #TODO: Externalize these to use properties as this is more secure
    @client.authorization.client_id = '857226781923.apps.googleusercontent.com'
    @client.authorization.client_secret = 'o_pT7P7g698ZZDih_dJMbKeh'

    @client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
    #@client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
    @client.authorization.redirect_uri = to('/oauthcallback')
    @client.authorization.code = params[:code] if params[:code]

    #if session[:token_id]
    #  # Load the access token here if it's available
    #  token_pair = TokenPair.get(session[:token_id])
    #  @client.authorization.update_token!(token_pair.to_hash)
    #end

    if @client.authorization.refresh_token && @client.authorization.expired?
      puts ">>> refreshing access token!"
      @client.authorization.fetch_access_token!
    end

    @cal = @client.discovered_api('calendar', 'v3')
    unless @client.authorization.access_token || request.path_info =~ /^\/oauth/
      puts ">>>> Redirecting to oauth authorization"
      redirect to('/oauthauthorize')
    end
  end

  get '/admin' do
    haml :"channels/index", :layout => :index
  end

  get '/oauthcallback' do
    client.authorization.fetch_access_token!
    # Persist the token here
    token_pair = if session[:token_id]
                   TokenPair.get(session[:token_id])
                 else
                   TokenPair.new
                 end
    token_pair.update_token!(@client.authorization)
    token_pair.save()
    session[:token_id] = token_pair.id
    redirect to('/')
  end

  get '/oauthauthorize' do
    redirect @client.authorization.authorization_uri.to_s, 303
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end
end