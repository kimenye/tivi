require_relative '../api_application'
require_relative '../AfricasTalkingGateway'
require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'

class TestHelper
  include SchedulerHelper
end

describe 'Sinatra helpers' do
  let(:helpers) { TestHelper.new }

  let(:service) { GCal4Ruby::Service.new }

  let(:api) { AfricasTalkingGateway.new("kimenye", "4f116c64a3087ae6d302b6961279fa46c7e1f2640a5a14a040d1303b2d98e560") }

  before(:all) do
    Subscriber.delete_all
    Subscription.delete_all
    Schedule.delete_all
    Show.delete_all
    Channel.delete_all
    SMSLog.delete_all


    test = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    tst = Channel.create(:name => 'Other Test', :code => 'Tst2', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')

    nine_thirty_am_show = Show.create(:channel => test, :name=> "9.30 AM Show", :description => "30 min show starting at 9.30 AM")
    ten_show = Show.create(:channel => test, :name=> "10 AM Show", :description => "30 min show starting at 10.00 AM")
    ten_thirty_show = Show.create(:channel => test, :name=> "10.30 AM Show", :description => "30 min show starting at 10.30 AM")
    channel_2_show = Show.create(:channel => tst, :name => "10 AM Show", :description => "30 min show starting at 10.00 AM on different channel")

    trev = Subscriber.create(:phone_number => "+254705866564")
    ten_reminder = Subscription.create(:subscriber => trev, :show => ten_show, :active => true)

    inactive_reminder_for_ten_o_clock_show = Subscription.create(:subscriber => trev, :show=> nil, :active => false, :show_name => 'Does not exist')

    service.authenticate "guide@tivi.co.ke", "sproutt1v!"
  end

  after(:all) do
    #at the end of all the methods being run
  end

  it "should return only the sms that match the TIVI filter" do
    messages = helpers.fetch_messages(api, 385)
    puts ">> messages #{messages.to_json}"
    messages.should_not be_nil

    msg = messages.first
    if !msg.nil?
      msg.text.downcase.match(/tivi/).should_not be_nil
    end
  end

  it "should return all the shows in the day" do
    test = Channel.find_by_code!('Tst')
    shows = helpers.sync_shows(service, test.calendar_id)
    shows.length.should eq(3)
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
end