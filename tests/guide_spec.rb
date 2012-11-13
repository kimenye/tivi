require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'
require_relative 'helpers_spec'
require_relative 'spec_helper'
require_relative '../guide'

set :environment, :test

class TestHelper
  include SchedulerHelper
end

describe 'The Tivi Guide App' do
  include Rack::Test::Methods
  include TestHelpers

  let(:helpers) { TestHelper.new }
  let(:guide) { GuideApp.new }

  def app
    GuideApp
  end
  
  before(:each) do
    common_delete
  end

  after(:all) do
    common_delete
  end
  
  it "Returns a list of scheduled shows for the rest of the day from time of query" do

    Schedule.delete_all
    Channel.delete_all

    tst = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    a_show = Show.create(:channel => tst, :name => "TestShow", :description => "My Test Show")

    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(11,30).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(9,00).utc, :end_time => helpers.today_at_time(10,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(12,30).utc, :end_time => helpers.today_at_time(13,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(3,30).utc, :end_time => helpers.today_at_time(4,30).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(1,30).utc, :end_time => helpers.today_at_time(2,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(6,30).utc, :end_time => helpers.today_at_time(7,00).utc)

    schedule_for_rest_of_day = helpers.get_schedule_for_rest_of_day(tst, helpers.today_at_time(9,30))

    schedule_for_rest_of_day.length.should eq(3)
    schedule_for_rest_of_day[0].start_time.should eq(helpers.today_at_time(9,00).utc)
    schedule_for_rest_of_day[1].start_time.should eq(helpers.today_at_time(10,30).utc)
    schedule_for_rest_of_day[2].start_time.should eq(helpers.today_at_time(12,30).utc)

  end

  it "Returns the current and next scheduled shows" do

    Schedule.delete_all
    Channel.delete_all

    tst = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    a_show = Show.create(:channel => tst, :name => "TestShow", :description => "My Test Show")

    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(11,30).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(9,30).utc, :end_time => helpers.today_at_time(10,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(12,30).utc, :end_time => helpers.today_at_time(13,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(3,00).utc, :end_time => helpers.today_at_time(4,30).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(1,30).utc, :end_time => helpers.today_at_time(2,00).utc)
    Schedule.create(:show => a_show, :start_time => helpers.today_at_time(6,30).utc, :end_time => helpers.today_at_time(7,00).utc)

    current_and_next_schedule = helpers.get_current_and_next_schedule(tst, helpers.today_at_time(3,30))

    current_and_next_schedule.length.should eq(2)
    current_and_next_schedule[0].start_time.should eq(helpers.today_at_time(3,00).utc)
    current_and_next_schedule[1].start_time.should eq(helpers.today_at_time(6,30).utc)

  end
  
  it "Returns the current show" do
    
    Schedule.delete_all
    Channel.delete_all

    tst = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    a_show = Show.create(:channel => tst, :name => "TestShow", :description => "My Test Show")

    sch = Schedule.create(:show => a_show, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(11,30).utc)
    sch02 = Schedule.create(:show => a_show, :start_time => helpers.today_at_time(11,30).utc, :end_time => helpers.today_at_time(12,30).utc)
    
    current_show = helpers.get_current_show_in_schedule(tst, helpers.today_at_time(10,45))
    
    current_show.should_not be_nil
    sch.id.should eq(current_show.id)
    
    test_show = helpers.get_current_show_in_schedule(tst, helpers.today_at_time(9,00))
    test_show.should be_nil
    
    test_show = helpers.get_current_show_in_schedule(tst, helpers.today_at_time(11,30))
    test_show.should_not be_nil
    
  end
  
  it "Returns categories form wordpress blog" do
    categories = helpers.get_categories
    categories.should_not be_nil
    
  end
  
  it "Searches for blog posts for a particular show" do
    
    data = {
      show_name: "Nairobi Half Life"
    }
    post "/blogs", data
    last_response.should be_ok
    
  end
  
end