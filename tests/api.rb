require_relative '../api_application'  # <-- your sinatra app
require 'spec/mocks'
require 'rspec-expectations'
require 'rack/test'
require 'pry'

set :environment, :test

describe 'The Tivi App' do
  include Rack::Test::Methods

  channel_json = "{ \"name\" : \"A test channel\", \"code\" : \"TC\" }"
  modified_json = "{ \"name\" : \"A test channel - modified\", \"code\" : \"TC-2\" }"


  def app
    ApiApplication
  end

  it "returns the correct version of the api" do
    get '/describe'
    last_response.should be_ok
    last_response.body.should == "{\"version\":\"1.0 \"}"
  end

  it "creates a tv channel" do
    before = Channel.find_by_code("TC")
    Channel.delete_all

    post "/channels", channel_json
    last_response.should be_ok
    created_id = last_response.body
    Channel.find_by_id!(created_id)
  end

  it "deletes a tv channel" do
    Channel.delete_all
    c = Channel.new
    c.code = "TC"
    c.name = "Test Channel"
    c.save!

    to_delete_id = c.id
    delete "/channels/#{to_delete_id.to_s}"

    last_response.should be_ok
    c = Channel.find_by_id(c.id)
    c.should be_nil
  end

  it "updates a tv channel" do
    Channel.delete_all
    c = Channel.new
    c.code = "TC"
    c.name = "Test Channel"
    c.save!

    patch "/channels/#{c.id}", modified_json

    last_response.should be_ok
    c = Channel.find_by_id(c.id)

    c.code.should == "TC-2"
  end

  it "returns tv channels" do
    get '/channels'
    channels = Channel.all
    last_response.should be_ok
    last_response.body.should == channels.to_json
  end

  it "returns a tv channel" do
    channel = Channel.first()
    if !channel.nil?
      get "/channels/#{channel.id}"
      last_response.should be_ok
      last_response.body.should == channel.to_json
    end
  end

  it "does not return a tv channel when there is no id" do
    get "/channels/"
    last_response.should_not be_ok
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