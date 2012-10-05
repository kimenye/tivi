require_relative '../api_application'
require_relative 'spec_helper'
require 'rspec-expectations'
require 'rack/test'

class TestHelper
  include SchedulerHelper
end

describe 'The User Experience' do
  include TestHelpers
  include Rack::Test::Methods
  
  let(:helpers) { TestHelper.new }

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
    subscription.active.should eq(true)
    show = Show.find_by_id!(subscription.show_id)
    ack = Message.find_by_type!(Message::TYPE_ACKNOWLEDGEMENT)
    ack.message_text.should eq("Thank you for your subscription. Reminders will be billed at 5KSH each. Sms 'STOP' to quit subscription")
  end

  it "should stop a subscription when a subscriber sends the stop keyword" do
    get "/sms_gateway?message_source=#{CGI::escape("254715866564")}&message_text=#{CGI::escape("TIVI 10 AM Show")}&message_destination=5566&trxID=3434435"
    subscriber = Subscriber.find_by_phone_number!("254715866564")
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should eq(true)
    get "/sms_gateway?message_source=#{CGI::escape("254715866564")}&message_text=#{CGI::escape("STOP")}&message_destination=5566&trxID=3434436"
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should eq(false)
  end

  it "should send an sms reminder when a show is about to begin" do
    get "/sms_gateway?message_source=#{CGI::escape("254725866564")}&message_text=#{CGI::escape("TIVI 10 AM Show")}&message_destination=5566&trxID=3434437"
    subscriber = Subscriber.find_by_phone_number!("254725866564")
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should eq(true)

    get "/reminders?username=guide@tivi.co.ke&password=sproutt1v!"
    last_response.should be_ok
    last_response.body.should == { :success => true }.to_json
    message = Message.find_by_subscriber_id_and_type!(subscriber.id, Message::TYPE_REMINDER)
    message.subscriber.should eq(subscriber)
  end
  
  it "should not send an acknowledgement for a show that has been misspelt" do
    get "/sms_gateway?message_source=#{CGI::escape("254701234567")}&message_text=#{CGI::escape("TIVI 10 MA Show")}&message_destination=5566&trxID=3434438"

    subscriber = Subscriber.find_by_phone_number!("254701234567")
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should eq(false)
    subscription.misspelt.should eq(true)
  end
  
  it "should send a message to the admin for a show that has been misspelt" do
    
    Message.delete_all
    Admin.delete_all
    admin = Admin.create!(:email => "mine@mine.com", :phone_number => "254722734912", :password => "mine")
    
    get "/sms_gateway?message_source=#{CGI::escape("254721234567")}&message_text=#{CGI::escape("TIVI 10 MA Show")}&message_destination=5566&trxID=3434439"

    subscriber = Subscriber.find_by_phone_number!("254721234567")
    subscription = Subscription.find_by_subscriber_id!(subscriber.id)
    subscription.active.should eq(false)
    subscription.misspelt.should eq(true)
    
    url = "http://example.org/admin/console/mobile/#{admin.id}"
    shortened_url = helpers.shorten_url(url)
    msg = Message.find_by_type!(Message::TYPE_ADMIN)
    msg.message_text.should eq("Click on the link to resolve the subscription: #{shortened_url}")
  end
end