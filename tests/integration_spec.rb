require_relative '../api_application'
require_relative 'spec_helper'
require 'rspec-expectations'
require 'rack/test'

describe 'The User Experience' do
  include TestHelpers
  include Rack::Test::Methods

  def app
    ApiApplication
  end

  before(:all) do
    common_delete
    reset_app

    set :environment, :test
    ktn = Channel.first
    post "/channels/sync/#{ktn.id}"
  end

  after(:all) do
    common_delete
  end

  it "should be test" do
    test?.should eq(true)
  end

  it "should send an acknowledgement for a show that exists" do
    get "/sms_gateway?message_source=#{CGI::escape("254705866564")}&message_text=#{CGI::escape("TIVI 10 AM Show")}&message_destination=5566&trxID=3434434"

    incoming_sms = SMSLog.find_by_external_id!(3434434)
    subscriber = Subscriber.find_by_phone_number!("254705866564")
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should be(true)
    show = Show.find_by_id!(subscription.show_id)
    ack = Message.find_by_type!(Message::TYPE_ACKNOWLEDGEMENT)
  end
end