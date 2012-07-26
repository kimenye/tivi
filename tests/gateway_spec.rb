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
end