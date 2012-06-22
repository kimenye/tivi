require_relative '../api_application'  # <-- your sinatra app
require 'spec/mocks'
require 'rack/test'

set :environment, :test

describe 'The Tivi App' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it "returns the correct version of the api" do
    get '/api/describe'
    last_response.should be_ok
    last_response.body.should == "{\"version\":\"1.0 \"}"
  end
end