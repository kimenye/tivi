require_relative '../admin'
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
    authorize 'guide@tivi.co.ke', 'sproutt1v!'
    get '/'
    last_response.should be_ok
  end
end
