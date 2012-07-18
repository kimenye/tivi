require_relative '../api_application'
require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'

set :environment, :test

class TestHelper
  include SchedulerHelper
end

describe 'The Tivi App' do
  include Rack::Test::Methods

  ktn = {
      name: "Kenya Television Network",
      code: "KTN",
      calendar_id: "tivi.co.ke_1aku43rv679bbnj9r02coema98@group.calendar.google.com"
  }

  kbc = {
      name: "Kenya Broadcasting Corporation",
      code: "KBC",
      calendar_id: "tivi.co.ke_5akei4jnt1hrjdmvb8vvvn6pis@group.calendar.google.com"
  }

  briefcase_inc = {
      name: "Briefcase Inc",
      description: "Charles, a university graduate, and Ben, a high school drop out, run into each other years after high school, and chance upon the idea of starting a business together. The only thing is, they hadn't really planned it, and Charles' dad, a retired traditionalist who believes in \"the system\", is ready to take advantage of any loopholes in their lack of planning to force them back into the system, with hilarious results."
  }

  hostel = {
      name: "Hostel",
      description: "Follow the campus students"
  }

  sms_response = {
      :payload => {
          :success => "true"
      }
  }

  def app
    ApiApplication
  end


  before(:each) do
    Subscriber.delete_all
    Subscription.delete_all
    Schedule.delete_all
    Show.delete_all
    Channel.delete_all
    SMSLog.delete_all
  end

  let(:helpers) { TestHelper.new }

  it "resets the data to a meaningful state" do
    get '/reset'
    last_response.should_not be_ok
    last_response.body.should == { :error => "Invalid credentials to reset"}.to_json

    c = Channel.create(:code => "NTV", :name=> "Nation TV")
    Show.create(:name => "News", :channel=> c)
    Channel.empty?.should be_false
    Show.empty?.should be_false

    get "/reset?username=#{CGI::escape("guide@tivi.co.ke")}&password=#{CGI::escape("sproutt1v!")}&create=false"
    last_response.should be_ok
    last_response.body.should == { :success => true}.to_json

    Channel.empty?.should be_true
    Show.empty?.should be_true

    get "/reset?username=#{CGI::escape("guide@tivi.co.ke")}&password=#{CGI::escape("sproutt1v!")}&create=true"
    last_response.should be_ok
    last_response.body.should == { :success => true}.to_json

    Channel.empty?.should be_false
  end

  it "returns the correct version of the api" do
    get '/describe'
    last_response.should be_ok
    last_response.body.should == "{\"version\":\"1.0 \"}"
  end

  it "creates a tv channel" do
    Channel.delete_all

    post "/channels", ktn.to_json
    last_response.should be_ok
    created_id = last_response.body
    Channel.find_by_id!(created_id)
  end

  it "deletes a tv channel" do
    Channel.delete_all
    c = Channel.new
    c.code = "TC"
    c.name = "Test Channel"
    c.calendar_id = "fsdfdsf"
    c.save!

    to_delete_id = c.id
    delete "/channels/#{to_delete_id.to_s}"

    last_response.should be_ok
    c = Channel.find_by_id(c.id)
    c.should be_nil
  end

  it "updates a tv channel" do
    Channel.delete_all
    c = Channel.new
    c.code = ktn[:code]
    c.name = ktn[:name]
    c.calendar_id = ktn[:calendar_id]
    c.save!

    patch "/channels/#{c.id}", kbc.to_json

    last_response.should be_ok
    c = Channel.find_by_id(c.id)

    c.code.should == kbc[:code]
  end

  it "returns tv channels" do
    get '/channels'
    channels = Channel.all
    last_response.should be_ok
    last_response.body.should == channels.to_json
  end

  it "returns a tv channel" do
    channel = Channel.first()
    if !channel.nil?
      get "/channels/#{channel.id}"
      last_response.should be_ok
      last_response.body.should == channel.to_json
    end
  end

  it "does not return a tv channel when there is no id" do
    get "/channels/"
    last_response.should_not be_ok
  end

  it "returns tv shows" do
    get '/shows'
    shows = Show.all
    last_response.should be_ok
    last_response.body.should == shows.to_json
  end

  it "creates a tv show" do
    Show.delete_all

    first_or_ktn = Channel.first_or_create(ktn)

    post "/shows", briefcase_inc.update({ channel: first_or_ktn.id.to_s }).to_json
    last_response.should be_ok
    created_id = last_response.body
    Show.find_by_id!(created_id)
  end

  it "does not create tv show with no channel" do
    Show.delete_all
    briefcase_inc.delete(:channel)
    post "/shows", briefcase_inc.to_json
    last_response.should_not be_ok
  end

  it "returns a tv show" do
    show = Show.first()
    if !show.nil?
      get "/shows/#{show.id}"
      last_response.should be_ok
      last_response.body.should == show.to_json
    end
  end

  it "deletes a tv show" do
    first_or_ktn = Channel.first_or_create(ktn)
    briefcase_inc_with_channel = briefcase_inc.update({ channel: first_or_ktn.id.to_s })

    c = Show.first_or_create(briefcase_inc_with_channel)

    to_delete_id = c.id
    delete "/shows/#{to_delete_id.to_s}"

    last_response.should be_ok
    c = Show.find_by_id(c.id)
    c.should be_nil
  end

  it "updates a tv show" do
    first_or_ktn = Channel.first_or_create(ktn)
    briefcase_inc_with_channel = briefcase_inc.update({ channel: first_or_ktn.id.to_s })
    briefcase_inc_with_channel.update({ description: "Short desc"})

    c = Show.first_or_create(briefcase_inc_with_channel)

    patch "/shows/#{c.id}", briefcase_inc_with_channel.to_json

    last_response.should be_ok
    c = Show.find_by_id(c.id)

    c.description.should == briefcase_inc_with_channel[:description]
  end

  it "returns only the shows for a specific channel" do
    ktn = Channel.create!(ktn)
    kbc = Channel.create!(kbc)

    Show.create(briefcase_inc.update({ channel: kbc }))
    Show.create(hostel.update({ channel: ktn }))
    Show.create({ channel: ktn, name: "KTN Today", description: "KTN News in the morning" })

    all_ctr = Show.count
    all_ctr.should == 3

    get "/channels/shows/#{ktn.id.to_s}"
    last_response.should be_ok
    JSON.parse(last_response.body).length.should == 2
  end

  it "returns the subscribers saved" do
    get "/subscribers"
    last_response.should be_ok
    last_response.body.should == Subscriber.all.to_json
  end

  it "should sync a shows schedule if it has not been done" do
    test = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    post "/channels/sync/#{test.id}"

    last_response.should be_ok
    Schedule.all.length.should eq(3)
  end

  it "should return only the scheduled shows for the specified date" do
    test = Channel.create(:name => 'Test', :code => 'Tst', :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com')
    ten_show = Show.create(:channel => test, :name=> "10 AM Show", :description => "30 min show starting at 10.00 AM")

    tomorrow = Schedule.create(:show => ten_show, :start_time => (helpers.today_at_time(10,30) + (24 * 3600)).utc, :end_time => (helpers.today_at_time(10,30) + (24 * 3600)).utc)
    today = Schedule.create(:show => ten_show, :start_time => helpers.today_at_time(10,30).utc, :end_time => helpers.today_at_time(10,30).utc)

    Schedule.all.length.should eq(2)

    get "/channels/schedule/#{test.id}"
    last_response.should be_ok

    last_response.body.should == [today].to_json

    get "/channels/schedule/#{test.id}?when=#{CGI::escape(tomorrow.start_time.to_s)}"
    last_response.should be_ok
    last_response.body.should == [tomorrow].to_json
  end
end