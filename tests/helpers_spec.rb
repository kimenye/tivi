require_relative '../api_application'
require_relative '../AfricasTalkingGateway'
require_relative 'spec_helper'
require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'

class TestHelper
  include SchedulerHelper
end

describe 'Sinatra helpers' do
  include TestHelpers

  let(:helpers) { TestHelper.new }

  let(:service) { GCal4Ruby::Service.new }

  let(:api) { AfricasTalkingGateway.new("kimenye", "4f116c64a3087ae6d302b6961279fa46c7e1f2640a5a14a040d1303b2d98e560") }

  before(:all) do
    common_setup

    tst = Channel.create(:name => 'Other Test', :code => 'Tst2', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    channel_2_show = Show.create(:channel => tst, :name => "10 AM Show", :description => "30 min show starting at 10.00 AM on different channel")
    ten_reminder = Subscription.create(:subscriber => get_test_subscriber, :show => get_test_show, :active => true)
    inactive_reminder_for_ten_o_clock_show = Subscription.create(:subscriber => get_test_subscriber, :show=> nil, :active => false, :show_name => 'Does not exist')

    service.authenticate "guide@tivi.co.ke", "sproutt1v!"
  end

  after(:all) do
    common_delete
  end

  it "should return 410 as the latest SMS is there is no further sms" do
    SMSLog.delete_all
    helpers.get_latest_received_message_id.should eq(410)

    SMSLog.create(:external_id => 2)
    SMSLog.create(:external_id => 45)
    SMSLog.create(:external_id => 3)

    helpers.get_latest_received_message_id.should eq(45)

    SMSLog.delete_all
  end

  it "should return only the sms that match the TIVI filter" do
    messages = helpers.fetch_messages(api)
    messages.should_not be_nil

    msg = messages.first
    if !msg.nil?
      msg.text.downcase.match(/tivi/).should_not be_nil
    end
  end

  it "should return only the sms that have not been already saved" do
    SMSLog.delete_all
    SMSLog.create(:external_id => 411)

    messages = helpers.fetch_messages(api)
    messages.empty?.should be_true or messages.detect { |msg| msg.id.to_i == 411 }.should be_nil
  end

  it "should return all the shows in the day" do
    test = Channel.find_by_code!('Tst')
    shows = helpers.sync_shows(service, test.calendar_id)
    shows.length.should eq(3)
  end

  it "should get the correct show name regardless of case" do
    helpers._get_show_name_from_text("tivi machachari").should eq("machachari")
    helpers._get_show_name_from_text("tiVi Machachari").should eq("machachari")
  end

  it "should create an active subscription if it does not already exist" do
    mach = Show.create(:name => "Machachari")

    sms = SMSMessage.new("390","TIVI Machachari", "+254d705866564", "5259", "2012-07-18 07:49:01")
    subscription = helpers.create_subscription(sms)
    subscription.should_not be_nil
    subscription.show.id.should eq(mach.id)
    subscription.active.should be_true

    SMSLog.delete_all
  end

  it "should not create multiple in-active subscriptions" do
    person = Subscriber.first_or_create(:phone_number => "+254705866564")
    subscription = Subscription.create(:subscriber => person, :show_name => "blahBlah", :active => false)

    num_subscriptions = Subscription.count

    sub = helpers.create_subscription(SMSMessage.new("390", "TIVI BLAHBLAH", "+254705866564", "5259", "2012-07-18 07:49:01"))
    sub.should be_nil
    Subscription.count.should eq(num_subscriptions)
  end

  it "should schedule all the shows in the day" do
    s = Schedule.all
    s.length.should eq(0)
    test = Channel.find_by_code!('Tst')

    helpers.create_schedule(service, test)

    s = Schedule.all
    s.length.should eq(3)
  end

  it "should return the show starting in the next five minutes" do
    shows = helpers.get_shows_starting_in_duration(5, helpers.today_at_time(9,25))
    shows.length.should eq(1)
  end

  it "should not return a show from a time which a show isnt starting exist" do
    shows = helpers.get_shows_starting_in_duration(5, helpers.today_at_time(8,25))
    shows.length.should eq(0)
  end

  it "should return a reminder for a show starting in 5 minutes" do
    reminders = helpers.get_reminders(5, helpers.today_at_time(9,55))
    reminders.length.should eq(1)
  end

  it "should send sms reminders to the subscribers" do
    messages = helpers.send_reminders(api, 5, helpers.today_at_time(9,55))
    messages.length.should eq(1)
  end

  it "should return the scheduled shows for only the specified day and channel" do
    Schedule.delete_all
    test = Channel.find_by_code!('Tst')
    test2 = Channel.find_by_code!('Tst2')

    ten_show = Show.find_by_name_and_channel_id!('10 AM Show',test.id)
    ten_show2 = Show.find_by_name_and_channel_id!('10 AM Show',test2.id)

    Schedule.create(:show => ten_show, :start_time => (helpers.today_at_time(10,30) + (24 * 3600)).utc, :end_time => (helpers.today_at_time(10,30) + (24 * 3600)).utc)
    Schedule.create(:show => ten_show, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(10,30).utc)
    Schedule.create(:show => ten_show2, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(10,30).utc)

    Schedule.all.length.should eq(3)
    helpers.get_schedule_for_day(helpers.today_at_time(10,30), test).length.should eq(1)
  end

  it "should get the correct start of the week" do
    a_sunday = Time.local(2012,7,15,0,0,0)
    helpers._get_start_of_the_week(a_sunday).should eq(a_sunday)

    a_tuesday = Time.local(2012,7,17,0,0,0)
    helpers._get_start_of_the_week(a_tuesday).should eq(a_sunday)

    next_sunday = Time.local(2012,7,22,0,0,0)
    helpers._get_start_of_the_week(next_sunday).should eq(next_sunday)
  end

  it "should sync shows for a whole week from the start of the week" do
    Schedule.delete_all

    test = Channel.find_by_code!('Tst')
    shows_for_week = helpers.sync_shows_for_week(service, test.calendar_id)

    shows_for_week.length.should eq(21)
  end

  it "should return the earliest next air date for a show " do
    test_show = Show.find_by_name!("10 AM Show")

    Schedule.create(:show => test_show, :start_time => helpers.today_at_time(22,30).utc, :end_time => helpers.today_at_time(23,00).utc)
    Schedule.create(:show => test_show, :start_time => (helpers.today_at_time(22,30) + 24 * 3600).utc, :end_time => (helpers.today_at_time(23,00) + 24 * 3600).utc)

    helpers.get_next_time_scheduled(test_show).start_time.should eq(helpers.today_at_time(22,30).utc)
    Schedule.delete_all(:show_id => test_show.id)
  end

  it "should return the next air date for a show after the current date" do
    test_show = Show.find_by_name!("10 AM Show")

    Schedule.create(:show => test_show, :start_time => (helpers.today_at_time(22,30) - 24 * 3600).utc, :end_time => (helpers.today_at_time(23,00) - 24 * 3600).utc)
    Schedule.create(:show => test_show, :start_time => (helpers.today_at_time(22,30) + 24 * 3600).utc, :end_time => (helpers.today_at_time(23,00) + 24 * 3600).utc)

    helpers.get_next_time_scheduled(test_show).start_time.should eq((helpers.today_at_time(22,30) + 24 * 3600).utc)

    Schedule.delete_all(:show_id => test_show.id)
  end

  it "should return empty for the next air date for a show if it has already aired that week" do
    test_show = Show.find_by_name!("10 AM Show")

    Schedule.create(:show => test_show, :start_time => (helpers.today_at_time(22,30) - 24 * 3600).utc, :end_time => (helpers.today_at_time(23,00) - 24 * 3600).utc)

    helpers.get_next_time_scheduled(test_show).should be_nil

    Schedule.delete_all(:show_id => test_show.id)
  end

  it "should inform the subscriber on how to opt out" do

  end
end