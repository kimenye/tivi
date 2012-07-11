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
    last_response.should_not be_ok
  end
end
