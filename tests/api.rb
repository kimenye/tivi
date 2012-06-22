require_relative '../api_application'  # <-- your sinatra app
require 'spec/mocks'
require 'rspec-expectations'
require 'rack/test'

set :environment, :test

describe 'The Tivi App' do
  include Rack::Test::Methods

  def app
    ApiApplication
  end

  it "returns the correct version of the api" do
    get '/api/describe'
    last_response.should be_ok
    last_response.body.should == "{\"version\":\"1.0 \"}"
  end

  it "returns tv channels" do
    get '/api/channels'
    channels = Channel.all
    last_response.should be_ok
    last_response.body.should == channels.to_json
  end

  it "returns a tv channel" do
    channel = Channel.first()
    if !channel.nil?
      get "/api/channel/#{channel.id}"
      last_response.should be_ok
      last_response.body.should == channel.to_json
    end
  end

  it "returns tv shows" do
    get '/api/shows'
    shows = TvShow.all
    last_response.should be_ok
    last_response.body.should == shows.to_json
  end
  
  it "returns a tv show" do
    show = TvShow.first()
    if !show.nil?
      get "/api/show/#{show.id}"
      last_response.should be_ok
      last_response.body.should == show.to_json
    end  
  end
end