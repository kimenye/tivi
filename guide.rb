require 'rubygems'
require 'sinatra'
require 'pry'
require 'haml'
require 'time'
require "xmlrpc/client"
require "httparty"
require 'sinatra/reloader' if development? or test?
require 'yaml'
YAML::ENGINE.yamler = 'syck'

class GuideApp < Sinatra::Base

  helpers SchedulerHelper
 
  post '/blogs' do
    
    data = cache_data
    data.to_json
    
  end

  get '/' do

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

    haml :"guide/mobile", :layout => :guide_layout, :locals => {:channel_summary => channel_summary, :channel_complete => channel_complete }

  end
  
end