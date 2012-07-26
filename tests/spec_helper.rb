require 'rspec-expectations'
require 'rack/test'
require 'dm-core'
require_relative '../models'

module TestHelpers

  def common_setup
    common_delete
    test = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    nine_thirty_am_show = Show.create(:channel => get_test_channel, :name=> "9.30 AM Show", :description => "30 min show starting at 9.30 AM")
    ten_show = Show.create(:channel => get_test_channel, :name=> "10 AM Show", :description => "30 min show starting at 10.00 AM")
    ten_thirty_show = Show.create(:channel => get_test_channel, :name=> "10.30 AM Show", :description => "30 min show starting at 10.30 AM")
    Subscriber.create(:phone_number => "+254705866564")
  end

  def common_delete
    Subscriber.delete_all
    Subscription.delete_all
    Schedule.delete_all
    Show.delete_all
    Channel.delete_all
    SMSLog.delete_all
  end

  def get_test_subscriber
    Subscriber.find_by_phone_number!("+254705866564")
  end

  def get_test_show
    Show.find_by_name!("10 AM Show")
  end

  def get_test_channel
    Channel.find_by_code!('Tst')
  end
end