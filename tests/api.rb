require_relative '../api_application'  # <-- your sinatra app
require 'spec/mocks'
require 'rspec-expectations'
require 'rack/test'
require 'pry'
require 'json'

set :environment, :test

describe 'The Tivi App' do
  include Rack::Test::Methods

  ktn = {
      name: "Kenya Television Network",
      code: "KTN"
  }

  kbc = {
      name: "Kenya Broadcasting Corporation",
      code: "KBC"
  }

  briefcase_inc = {
      name: "Briefcase Inc",
      description: "Charles, a university graduate, and Ben, a high school drop out, run into each other years after high school, and chance upon the idea of starting a business together. The only thing is, they hadn't really planned it, and Charles' dad, a retired traditionalist who believes in \"the system\", is ready to take advantage of any loopholes in their lack of planning to force them back into the system, with hilarious results."
  }

  hostel = {
      name: "Hostel",
      description: "Follow the campus students"
  }

  def app
    ApiApplication
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
    Show.delete_all
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
    Show.delete_all
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
    Show.delete_all
    Channel.delete_all
    ktn = Channel.create!(ktn)
    kbc = Channel.create!(kbc)

    Show.create(briefcase_inc.update({ channel: kbc }))
    Show.create({ channel: ktn })

    all_ctr = Show.count
    all_ctr.should == 2



    get "/channels/shows/#{ktn.id.to_s}"
    last_response.should be_ok
    JSON.parse(last_response.body).length.should == 1
  end
end