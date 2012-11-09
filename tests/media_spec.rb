
require_relative '../media'
require_relative 'helpers_spec'
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
  include TestHelpers

  def app
    MediaApp
  end

  it "A channel has a logo" do
    Schedule.delete_all
    Show.delete_all
    Channel.delete_all

    logo = File.open(Dir.pwd + "/static/images/channels/citizen.png")
    logo.should_not be_nil

    c = Channel.create(:name => 'Test',
                       :code => 'Tst',
                       :calendar_id => 'tivi.co.ke_a0pt1qvujhtbre4u8b3s5jl25k@group.calendar.google.com',
                       :logo => logo)

    c.logo.type.should == "image/png"
    c.logo.size.should == 4447

    url = "/media/images/#{c.logo.id}"
    get url
    last_response.should be_ok
  end

end