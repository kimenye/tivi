require 'rubygems'
require 'sinatra'
require 'haml'
require 'pry'
require_relative 'api_application'

class TiviApp < Sinatra::Base

  helpers SchedulerHelper

  configure do
    use Rack::Session::Pool, :expire_after => 86400 # 1 day
    set :protection, :except => :frame_options
  end

  get '/' do
    haml :home, :layout => :layout
  end

  get '/test' do

    channel_summary = Array.new
    channel_complete = Array.new
    channels = Channel.all
    channels.each do |channel|
      temp_hash1 = Hash.new
      temp_hash2 = Hash.new
      current_and_next_schedule = get_current_and_next_schedule(channel)
      schedule_for_rest_of_day = get_schedule_for_rest_of_day(channel)
      temp_hash1["channel"] = channel
      temp_hash1["shows"] = current_and_next_schedule
      channel_summary.push(temp_hash1)
      temp_hash2["channel"] = channel
      temp_hash2["shows"] = schedule_for_rest_of_day
      channel_complete.push(temp_hash2)
    end
    #binding.pry

    haml :guide_frame, :layout => :guide_frame_layout, :locals => {:channel_summary => channel_summary, :channel_complete => channel_complete }
  end

  configure do
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end
end