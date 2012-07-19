require_relative '../admin'
require_relative '../api_application'
require 'spec/mocks'
require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'

set :environment, :test

describe 'The Tivi Administration App' do
  include Rack::Test::Methods

  def app
    AdminApp
  end

  def login

  end

  username = 'guide@tivi.co.ke'
  password = 'sproutt1v!'

  it "should not be able to access the admin area without login credentials" do
    get '/'
    last_response.status.should == 401
  end

  it "should not be able to access the admin area without the correct credentials" do
    authorize 'bad', 'boy'
    get '/'
    last_response.status.should == 401
  end

  it "should authenticate the user with the correct login details" do
    authorize username, password
    get '/'
    last_response.should be_ok
  end

  it "should show the name of channel when viewing the schedule for a channel" do

    channel = Channel.first_or_create(:code => "KTN", :name => "Kenya TV Network")

    authorize username, password
    get "/schedule/#{channel.id.to_s}"
    last_response.should be_ok
    last_response.body.should =~ /#{channel.name}/
  end
end
