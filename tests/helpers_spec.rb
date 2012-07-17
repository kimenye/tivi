require_relative '../api_application'
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

  before(:all) do
    #puts ">> At the beginning of time"
    Subscriber.delete_all
    Subscription.delete_all
    Schedule.delete_all
    Show.delete_all
    Channel.delete_all


    test = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')

    nine_thirty_am_show = Show.create(:channel => test, :name=> "9.30 AM Show", :description => "30 min show starting at 9.30 AM")
    ten_show = Show.create(:channel => test, :name=> "10.00 AM Show", :description => "30 min show starting at 10.00 AM")
    ten_thirty_show = Show.create(:channel => test, :name=> "10.30 AM Show", :description => "30 min show starting at 10.30 AM")

    trev = Subscriber.create(:phone_number => "+254705866564")
    ten_reminder = Subscription.create(:subscriber => trev, :show => ten_show, :active => true)

    inactive_reminder_for_ten_o_clock_show = Subscription.create(:subscriber => trev, :show=> nil, :active => false, :show_name => 'Does not exist')

    service.authenticate "guide@tivi.co.ke", "sproutt1v!"
  end

  after(:all) do
    #at the end of all the methods being run
  end

  it "should return seconds for mins" do
    helpers.get_seconds_from_min(5).should eql(300)
  end

  it "should return the right time of the day" do
    t = helpers.today_at_time(9,30)
    now = Time.now
    t.year.should eq(now.year)
    t.month.should eq(now.month)
    t.day.should eq(now.day)
    t.hour.should eq(9)
    t.min.should eq(30)
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

  it "should not return a reminder for a subscription that is not active" do
    reminders = helpers.get_reminders(5, helpers.today_at_time(9,55))
    reminders.length.should eq(1)
  end

end