require_relative '../api_application'
require_relative '../sms_gateway'
require_relative 'spec_helper'
require 'rspec-expectations'
require 'rack/test'


describe 'Gateway methods' do
  include TestHelpers

  let(:gateway) { RoamTechGateway.new }

  before(:all) do
    common_delete
  end

  it "should create an SMS log from a set of parameters" do
    SMSLog.all.length.should eq(0)
    params = {
        :message_source => "254705866564",
        :trxID => "33434",
        :message_text => "TIVI Machachari",
        :message_destination => "5566"
    }

    sms = gateway.receive_notification(params)
    sms.should_not be_nil
    SMSLog.all.length.should eq(1)
    SMSLog.delete_all
  end

  it "should return only the sms that have not been already saved" do
    SMSLog.create(:external_id => 411)
    before = SMSLog.all.length
    params = {
        :message_source => "254705866564",
        :trxID => 411,
        :message_text => "TIVI Machachari",
        :message_destination => "5566"
    }

    sms = gateway.receive_notification(params)
    sms.should be_nil
    SMSLog.all.length.should eq(before)
    SMSLog.delete_all
  end

  it "should send a message to a recipient" do
    id = gateway.send_message("254714423224", "response message")
    id.should_not be_nil
    Message.all.length.should eq(1)
    Message.delete_all
  end

  it "should process the response correctly" do
    rsp = gateway.process_response("DN1701 | 870851")
    rsp.should eq("870851")
  end

  #it "should send a real text" do
  #  id = gateway.send_message("254705866564", "This is a test message",Message::TYPE_ACKNOWLEDGEMENT,nil,nil,true)
  #end
end