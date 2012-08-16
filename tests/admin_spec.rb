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

  it "should not be able to access the admin area without login credentials" do
    get '/'
    last_response.status.should == 401
  end

  it "should not be able to access the admin area without the correct credentials" do
    authorize 'bad', 'boy'
    get '/'
    last_response.status.should == 401
  end

  it "should use the admins email and password" do
    admin = Admin.create!({ :email => "me@somewhere.com", :password => "abcdefghi", :phone_number => "0705332222" })
    authorize admin.email, admin.password
    get '/'
    last_response.should be_ok
  end
end
